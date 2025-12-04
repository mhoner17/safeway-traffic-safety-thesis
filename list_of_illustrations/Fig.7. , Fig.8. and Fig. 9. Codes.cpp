import matplotlib
matplotlib.use('TkAgg')
import pandas as pd
import matplotlib.pyplot as plt
import os
import re

# exceldeki kaza verisini buradan içeri alıyorum
df = pd.read_excel("kaza_adresli.xlsx")

# vilnius ve 2020–2024 yılları için satırları filtreliyorum
vilnius_df = df[
    (df['Metai'].between(2020, 2024)) &
    (df['address'].str.contains("Vilnius", case=False, na=False))
].copy()

# adres içinden regex ile sokak adını çekiyorum
regex_pattern = r'(\b[\wÀ-ž\s\-\.]+?\s?(g\.|pl\.|pr\.|kel\.|al\.|gatvė|prospektas|kelias|alėja))'
vilnius_df['clean_street'] = vilnius_df['address'].str.extract(regex_pattern, expand=False)[0]
vilnius_df['clean_street'] = vilnius_df['clean_street'].fillna("Bilinmeyen")

# sokak adı bulunamazsa yedek çıkarım yapan küçük fonksiyon
def backup_street(parts, existing):
    if existing != "Bilinmeyen":
        return existing
    for p in parts:
        if re.search(r'\b(g\.|pl\.|pr\.|kel\.|al\.|gatvė|prospektas|kelias|alėja)\b', p.strip(), re.IGNORECASE):
            return p.strip()
    return parts[2].strip() if len(parts) >= 3 else "Bilinmeyen"

# adresleri virgüle göre parçalayıp final sokak ismini belirliyorum
vilnius_df['address_parts'] = vilnius_df['address'].str.split(',')
vilnius_df['final_street'] = [
    backup_street(parts, original)
    for parts, original in zip(vilnius_df['address_parts'], vilnius_df['clean_street'])
]

# sadece laisvės pr. satırlarını ve koordinatlarını alıyorum
laisves_coords = vilnius_df[
    (vilnius_df['final_street'] == 'Laisvės pr.') &
    (vilnius_df['Latitude'].notna()) &
    (vilnius_df['Longitude'].notna())
][['Metai', 'Latitude', 'Longitude']]

# her yılı farklı renkte olacak şekilde saçılım grafiği çiziyorum
plt.figure(figsize=(12, 6))
for year in range(2020, 2025):
    subset = laisves_coords[laisves_coords['Metai'] == year]
    plt.scatter(subset['Longitude'], subset['Latitude'], label=str(year), alpha=0.7)

# başlık ve eksen isimlerini ayarlıyorum
plt.title("Laisvės pr. (Vilnius) – 2020–2024 Yılları Kaza Noktaları")
plt.xlabel("Longitude")
plt.ylabel("Latitude")
plt.legend(title="Yıl")
plt.grid(True, linestyle='--', linewidth=0.5)
plt.tight_layout()

# çıktıyı kaydedeceğim klasörü ve dosya yolunu hazırlıyorum
output_dir = "output"
os.makedirs(output_dir, exist_ok=True)

output_path = os.path.join(output_dir, "laisves_pr_vilnius_2020_2024_kaza_noktalari.png")
plt.savefig(output_path, dpi=300)
plt.show()

print(f"✅ Grafik başarıyla kaydedildi: {output_path}")
