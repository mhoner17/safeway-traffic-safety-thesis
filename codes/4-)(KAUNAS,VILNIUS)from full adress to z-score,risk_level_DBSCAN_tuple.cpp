import pandas as pd
import numpy as np
import re
from sklearn.cluster import DBSCAN

#   1. Veri Yükleme  
df = pd.read_excel("kaza_adresli.xlsx")  # Excel dosyanı buraya koy

#   2. Hedef Şehirler  
target_cities = ['Kaunas', 'Vilnius']
tum_sonuclar = []

#   3. Yardımcı Fonksiyonlar  

def risk_seviyesi(z):
    if z > 1.0:
        return 'High Risk'
    elif z >= -0.5:
        return 'Medium Risk'
    else:
        return 'Low Risk'

def apply_dbscan_for_city(city_df, sokak, risk, z_score):
    coords = city_df[['Latitude', 'Longitude']].to_numpy()
    coords_rad = np.radians(coords)

    if len(coords_rad) < 3:
        return []

    eps_meters = 200
    earth_radius = 6371000
    eps = eps_meters / earth_radius
    min_samples = 3

    db = DBSCAN(eps=eps, min_samples=min_samples, metric='haversine')
    labels = db.fit_predict(coords_rad)

    results = []
    for label in set(labels):
        if label == -1:
            continue
        cluster_points = coords[labels == label]
        if len(cluster_points) == 0:
            continue
        center_lat = cluster_points[:, 0].mean()
        center_lon = cluster_points[:, 1].mean()
        results.append((center_lat, center_lon))
    return results

#   4. Sokak Çekme Regex ve Yedek Fonksiyon  

regex_pattern = r'(\b[\wÀ-ž\s\-\.]+?\s?(g\.|pl\.|pr\.|kel\.|al\.|gatvė|prospektas|kelias|alėja))'

def backup_street(parts, existing):
    if existing != "Bilinmeyen":
        return existing
    for p in parts:
        if re.search(r'\b(g\.|pl\.|pr\.|kel\.|al\.|gatvė|prospektas|kelias|alėja)\b', p.strip(), re.IGNORECASE):
            return p.strip()
    return parts[2].strip() if len(parts) >= 3 else "Bilinmeyen"

#   5. Şehir Döngüsü  
for city in target_cities:
    city_df = df[
        (df['Metai'].between(2020, 2024)) &
        (df['address'].str.contains(city, case=False, na=False)) &
        df['Latitude'].notna() &
        df['Longitude'].notna()
    ].copy()

    city_df['clean_street'] = city_df['address'].str.extract(regex_pattern, expand=False)[0]
    city_df['clean_street'] = city_df['clean_street'].fillna("Bilinmeyen")
    city_df['address_parts'] = city_df['address'].str.split(',')

    city_df['final_street'] = [
        backup_street(parts, original)
        for parts, original in zip(city_df['address_parts'], city_df['clean_street'])
    ]

    city_df['Koordinat'] = list(zip(city_df['Latitude'], city_df['Longitude']))

    #   6. Z-score Hesaplama  
    risk_df = city_df.groupby('final_street').agg(
        Toplam_Kaza=('Koordinat', 'count')
    ).reset_index()

    mean = risk_df['Toplam_Kaza'].mean()
    std = risk_df['Toplam_Kaza'].std()

    risk_df['Z_score'] = (risk_df['Toplam_Kaza'] - mean) / std
    risk_df['Risk_Seviyesi'] = risk_df['Z_score'].apply(risk_seviyesi)

    #   7. DBSCAN Uygulaması (Yüksek ve Orta Riskliler)  
    riskli_sokaklar = risk_df[risk_df['Risk_Seviyesi'].isin(['High Risk', 'Medium Risk'])]

    for _, row in riskli_sokaklar.iterrows():
        sokak = row['final_street']
        z_score = row['Z_score']
        risk = row['Risk_Seviyesi']

        sokak_coords_df = city_df[city_df['final_street'] == sokak]
        merkezler = apply_dbscan_for_city(sokak_coords_df, sokak, risk, z_score)

        if merkezler:
            tum_sonuclar.append({
                'Sehir': city,
                'Sokak': sokak,
                'Risk_Seviyesi': risk,
                'Z_score': z_score,
                'Toplam_Kume_Sayisi': len(merkezler),
                'Toplam_Kaza': len(sokak_coords_df),
                'Koordinat_Tuple': merkezler
            })

#   8. Final DataFrame  
tum_sehirler_df = pd.DataFrame(tum_sonuclar)

# Sonuç: her şehirdeki riskli sokaklar ve yoğunluk kümeleri listesi
print(tum_sehirler_df.head())  # örnek çıktı
