import matplotlib
matplotlib.use('TkAgg')  # pycharm / masaüstü ortamında pencere için böyle ayarladım
import pandas as pd
import matplotlib.pyplot as plt
import os

# veriyi csv dosyasından burada içeri alıyorum
df = pd.read_csv("k_k_v_accidents_data_lithuanian.csv")

# z-score sütununu alıyorum, boş (nan) olan satırları çıkarıyorum
z_scores = df["Z_score"].dropna()

# şekli ve eksenleri burada hazırlıyorum
plt.figure(figsize=(9, 5))
ax = plt.gca()

# z-score dağılımı için histogram çiziyorum
n, bins, patches = ax.hist(
    z_scores,
    bins=25,
    edgecolor="black",
    alpha=0.8
)

# tezde kullandığım risk eşiklerine göre dikey çizgiler ekliyorum
z_low = -0.5        # low / medium sınırı
z_high = 1.0        # medium / high sınırı

# şehir genelindeki ortalamayı (z = 0) kesikli çizgiyle gösteriyorum
ax.axvline(0, color="black", linestyle="--", linewidth=1, label="Mean (Z = 0)")

# risk seviyeleri için eşik çizgilerini ekliyorum
ax.axvline(z_low, color="tab:blue", linestyle=":", linewidth=1.5, label="Z = -0.5")
ax.axvline(z_high, color="tab:red", linestyle=":", linewidth=1.5, label="Z = 1.0")

# arka planı risk bölgelerine göre hafif renklendiriyorum, daha anlaşılır olsun diye
# low risk bölgesi (z < -0.5)
ax.axvspan(z_scores.min(), z_low, alpha=0.10, color="green")
# medium risk bölgesi (-0.5 ≤ z ≤ 1.0)
ax.axvspan(z_low, z_high, alpha=0.10, color="gold")
# high risk bölgesi (z > 1.0)
ax.axvspan(z_high, z_scores.max(), alpha=0.10, color="red")

# başlığı ve eksen isimlerini burada ayarlıyorum
ax.set_title("Z-score distribution of Lithuanian street accident frequencies", fontsize=12)
ax.set_xlabel("Z-score of street-level accident frequency", fontsize=11)
ax.set_ylabel("Number of streets", fontsize=11)

# alta risk seviyelerini açıklayan kısa not düşüyorum
ax.text(
    0.01, -0.23,
    "Risk level thresholds used in the thesis:\n"
    "Z < -0.5: Low Risk   |   -0.5 ≤ Z ≤ 1.0: Medium Risk   |   Z > 1.0: High Risk",
    transform=ax.transAxes,
    fontsize=9,
    va="top"
)

# hafif yatay grid çizgisi ve düzenleme
ax.grid(axis="y", linestyle="--", alpha=0.4)
plt.tight_layout()

# çıktıyı tezde kullanmak için yüksek çözünürlüklü png olarak kaydediyorum
output_path = os.path.join(os.getcwd(), "figure_zscore_distribution_lithuania.png")
plt.savefig(output_path, dpi=300)

# grafiği ekranda gösteriyorum
plt.show()

print("Figure saved to:", output_path)
