import pandas as pd
import matplotlib.pyplot as plt

# excel dosyasının yolunu burada tanımladım
file_path = "2020-2024m_EI-duomenys_viesinama.xlsx"

# ilgili sayfayı excelden okuyorum
df = pd.read_excel(file_path, sheet_name="2020-2024")

# sadece 2024 yılına ait satırları alıyorum
df_2024 = df[df["Metai"] == 2024]

# laikas sütunu boş olmayan kayıtları bırakıyorum
df_2024 = df_2024[df_2024["Laikas"].notnull()]

# laikas ondalık olduğu için 24 ile çarpıp saat bilgisini çıkarıyorum
df_2024["Hour"] = (df_2024["Laikas"] * 24).astype(int)

# 2 saatlik zaman dilimlerini burada tanımlıyorum
time_bins = list(range(0, 25, 2))  # 0, 2, 4, ..., 24
time_labels = [
   "00:00–02:00", "02:00–04:00", "04:00–06:00", "06:00–08:00",
   "08:00–10:00", "10:00–12:00", "12:00–14:00", "14:00–16:00",
   "16:00–18:00", "18:00–20:00", "20:00–22:00", "22:00–00:00"
]

# her kaydı ilgili zaman aralığına yerleştiriyorum
df_2024["Time Slot"] = pd.cut(df_2024["Hour"], bins=time_bins, labels=time_labels, right=False)

# her zaman dilimi için toplam kaza sayısını hesaplıyorum
time_slot_counts = df_2024["Time Slot"].value_counts().sort_index()
time_slot_counts_df = time_slot_counts.reset_index()
time_slot_counts_df.columns = ["Time Slot", "Accident Count"]

# çizgi grafiğini burada oluşturuyorum
plt.figure(figsize=(12, 6))
plt.plot(time_slot_counts_df["Time Slot"], time_slot_counts_df["Accident Count"], marker='o')
plt.title("Distribution of Accidents by Time Slot in 2024")
plt.xlabel("Time Slot")
plt.ylabel("Number of Accidents")
plt.xticks(rotation=45)
plt.grid(True)
plt.tight_layout()
plt.show()
