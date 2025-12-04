import pandas as pd
import matplotlib.pyplot as plt

# excel dosyasının yolunu burada tanımlıyorum
file_path = '2020-2024m_EI-duomenys_viesinama.xlsx'
df = pd.read_excel(file_path, sheet_name='2020-2024')

# laikas sütununda boş olan satırları atıyorum
df = df[df['Laikas'].notnull()]

# saat bilgisini datetime'a çevirip sadece saati alıyorum
df['Hour'] = pd.to_datetime(df['Laikas'], format='%H:%M:%S', errors='coerce').dt.hour

# çevrilemeyen (NaT olan) saatleri temizliyorum
df = df[df['Hour'].notnull()]

# her saat için kaza sayısını saydırıyorum
hourly_counts = df['Hour'].value_counts().sort_index()

# grafiği burada çizdiriyorum
plt.figure(figsize=(12, 6))
hourly_counts.plot(kind='bar', alpha=0.7)
plt.title('Traffic Accidents by Hour of the Day (2020–2024)', fontsize=14)
plt.xlabel('Hour of Day (0 = Midnight, 23 = 11PM)', fontsize=12)
plt.ylabel('Number of Accidents', fontsize=12)
plt.xticks(rotation=0)
plt.grid(axis='y', linestyle='--', alpha=0.6)
plt.tight_layout()
plt.show()
