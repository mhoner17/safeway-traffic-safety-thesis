import pandas as pd
import numpy as np
import re
from sklearn.cluster import DBSCAN


# 1. Veriyi oku
df = pd.read_excel("kaza_adresli.xlsx")


# 2. Klaipėda şehrine ve 2020–2024 yıllarına filtre uygula
klaipeda_df = df[
    (df['Metai'].between(2020, 2024)) &
    (df['address'].str.contains("Klaipėda", case=False, na=False))
].copy()


# 3. Sokak adını çıkar (regex + yedekleme)
regex_pattern = r'(\b[\wÀ-ž\s\-\.]+?\s?(g\.|pl\.|pr\.|kel\.|al\.|gatvė|prospektas|kelias|alėja))'
klaipeda_df['clean_street'] = klaipeda_df['address'].str.extract(regex_pattern, expand=False)[0]
klaipeda_df['clean_street'] = klaipeda_df['clean_street'].fillna("Bilinmeyen")

def backup_street(parts, existing):
    if existing != "Bilinmeyen":
        return existing
    for p in parts:
        if re.search(r'\b(g\.|pl\.|pr\.|kel\.|al\.|gatvė|prospektas|kelias|alėja)\b', p.strip(), re.IGNORECASE):
            return p.strip()
    return parts[2].strip() if len(parts) >= 3 else "Bilinmeyen"

klaipeda_df['address_parts'] = klaipeda_df['address'].str.split(',')
klaipeda_df['final_street'] = [
    backup_street(parts, original)
    for parts, original in zip(klaipeda_df['address_parts'], klaipeda_df['clean_street'])
]


# 4. Koordinatları filtrele
klaipeda_df = klaipeda_df[
    klaipeda_df['Latitude'].notna() & klaipeda_df['Longitude'].notna()
]
klaipeda_df['Koordinat'] = list(zip(klaipeda_df['Latitude'], klaipeda_df['Longitude']))


# 5. Z-score hesapla
risk_df = klaipeda_df.groupby('final_street').agg(
    Toplam_Kaza=('Koordinat', 'count')
).reset_index()

mean = risk_df['Toplam_Kaza'].mean()
std = risk_df['Toplam_Kaza'].std()
risk_df['Z_score'] = (risk_df['Toplam_Kaza'] - mean) / std

def risk_class(z):
    if z > 1.0:
        return 'High Risk'
    elif z >= -0.5:
        return 'Medium Risk'
    else:
        return 'Low Risk'

risk_df['Risk_Seviyesi'] = risk_df['Z_score'].apply(risk_class)


# 6. High & Medium Risk sokaklar için DBSCAN
eps_meters = 200
earth_radius = 6371000
eps = eps_meters / earth_radius
min_samples = 3

riskli_sokaklar = risk_df[risk_df['Risk_Seviyesi'].isin(['High Risk', 'Medium Risk'])]

sonuclar = []

for _, row in riskli_sokaklar.iterrows():
    sokak = row['final_street']
    z_score = row['Z_score']
    risk = row['Risk_Seviyesi']

    sokak_kazalari = klaipeda_df[klaipeda_df['final_street'] == sokak]
    coords = sokak_kazalari[['Latitude', 'Longitude']].to_numpy()
    if len(coords) < min_samples:
        continue
    coords_rad = np.radians(coords)

    db = DBSCAN(eps=eps, min_samples=min_samples, metric='haversine')
    labels = db.fit_predict(coords_rad)

    for label in set(labels):
        if label == -1:
            continue
        cluster_points = coords[labels == label]
        if len(cluster_points) == 0:
            continue
        center_lat = cluster_points[:, 0].mean()
        center_lon = cluster_points[:, 1].mean()

        sonuclar.append({
            'Sokak': sokak,
            'Risk_Seviyesi': risk,
            'Z_score': z_score,
            'Kume_No': int(label),
            'Kaza_Sayisi_Kumede': len(cluster_points),
            'Merkez_Latitude': center_lat,
            'Merkez_Longitude': center_lon
        })


# 7. Küme merkezlerini sokak bazında grupla
kume_df = pd.DataFrame(sonuclar)
kume_df['Koordinat_Tuple'] = list(zip(kume_df['Merkez_Latitude'], kume_df['Merkez_Longitude']))

summary = kume_df.groupby(['Sokak', 'Risk_Seviyesi', 'Z_score']).agg(
    Toplam_Kume_Sayisi=('Kume_No', 'count'),
    Toplam_Kaza=('Kaza_Sayisi_Kumede', 'sum'),
    Koordinat_Tuple=('Koordinat_Tuple', list)
).reset_index()