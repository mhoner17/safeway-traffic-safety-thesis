import pandas as pd
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
import re

# burada varsayılan çizim stilini seçmeye çalışıyorum
try:
   plt.style.use("seaborn-v0_8")
except OSError:
   plt.style.use("ggplot")

# kaza verilerini excelden içeri alıyorum
df = pd.read_excel("kaza_adresli.xlsx")
# çalışacağım yıl aralığını burada tanımladım
years = list(range(2020, 2025))
# yıl sütununu tam sayıya çeviriyorum ki filtrelemesi kolay olsun
df["Metai"] = df["Metai"].astype(int)

# adres bilgisinden sokak ismini çekmek için küçük bir fonksiyon
def extract_street(addr):
   if pd.isna(addr):
       return None
   addr = str(addr)
   pattern = r"([\wÀ-ž\.\- ]+?\s(?:g\.|pl\.|pr\.|kel\.|al\.|gatvė|prospektas|kelias|alėja))"
   m = re.search(pattern, addr)
   if m:
       return m.group(1).strip()
   parts = addr.split(",")
   if len(parts) > 1:
       return parts[1].strip()
   return addr.strip()

# her satır için yukarıdaki fonksiyonla sokak adını çıkarıyorum
df["Street"] = df["address"].apply(extract_street)

# klaipeda için en çok kaza olan sokakların yıllara göre trendini hazırlayan fonksiyon
def get_top_street_trend_klaipeda(n_top=5):
   city_df = df[
       (df["Metai"].between(2020, 2024)) &
       (df["address"].str.contains("Klaipėda|Klaipeda", case=False, na=False))
   ].copy()

   # sokaklara göre toplam kaza sayısını hesaplıyorum
   street_counts = (
       city_df.groupby("Street").size().sort_values(ascending=False)
   )
   # en çok kazaya sahip ilk n sokak
   top_streets = street_counts.head(n_top).index.tolist()

   # sadece bu seçilen sokakları filtreliyorum
   top_df = city_df[city_df["Street"].isin(top_streets)]

   # yıl + sokak kombinasyonuna göre tabloyu pivotluyorum
   trend_df = (
       top_df
       .groupby(["Metai", "Street"])
       .size()
       .unstack("Street")
       .reindex(years, fill_value=0)
   )
   return trend_df, top_streets

# burada bir şehrin top sokaklarını çizdirmek için genel bir fonksiyon var
def plot_city_topN(trend_df, city_name, streets, filename):
   fig, ax = plt.subplots(figsize=(11, 6))
   # her sokak için kullanacağım renk listesi
   colors = ["red", "gold", "green", "royalblue", "purple", "darkorange"]

   # her sokak için ayrı çizgi çiziyorum
   for i, street in enumerate(streets):
       y = trend_df[street].values
       label_text = f"{city_name} – {street}"
       ax.plot(
           years, y,
           marker="o",
           linewidth=2.5,
           markersize=7,
           color=colors[i % len(colors)],
           label=label_text
       )
       # nokta üstlerine kaza sayısını yazıyorum
       for x, val in zip(years, y):
           ax.annotate(
               f"{int(val)}",
               xy=(x, val),
               xytext=(0, 7),
               textcoords="offset points",
               ha="center",
               va="bottom",
               fontsize=9,
           )

   # grafik başlığı ve eksen isimleri
   ax.set_title(
       f"Annual Accidents on Top {len(streets)} Streets in {city_name} (2020–2024)",
       fontsize=16,
       fontweight="bold",
       pad=15
   )
   ax.set_xlabel("Year", fontsize=13)
   ax.set_ylabel("Number of accidents", fontsize=13)

   # x ekseninde yılları düzgün göstermek için
   ax.set_xticks(years)
   ax.tick_params(axis="both", labelsize=11)

   # yatay grid çizgileri ile okunabilirliği artırıyorum
   ax.yaxis.grid(True, linestyle="--", linewidth=0.7, alpha=0.7)
   ax.set_axisbelow(True)

   # üst ve sağ çerçeveyi kapatıyorum, daha sade dursun diye
   for spine in ["top", "right"]:
       ax.spines[spine].set_visible(False)

   # maksimum değere göre y ekseni sınırını biraz yukarıdan ayarlıyorum
   max_val = trend_df.values.max()
   ax.set_ylim(0, max_val * 1.25 if max_val > 0 else 1)

   # lejandı grafiğin dışına taşıyorum
   ax.legend(
       title="City – Street",
       fontsize=10,
       title_fontsize=11,
       loc="upper left",
       bbox_to_anchor=(1.02, 1.0),
       borderaxespad=0.
   )

   # grafik yerleşimini sıkılaştırıp yüksek çözünürlüklü kaydediyorum
   fig.tight_layout()
   fig.savefig(filename, dpi=500, bbox_inches="tight")
   plt.show()

# önce klaipeda için trend verisini ve sokak listesini alıyorum
klaipeda_trend, klaipeda_streets = get_top_street_trend_klaipeda(n_top=5)

# sonra bu veriyi çizdirip png olarak dışarı kaydediyorum
plot_city_topN(
   klaipeda_trend,
   "Klaipėda",
   klaipeda_streets,
   "klaipeda_top5_streets_annual_accidents_2020_2024.png"
)
