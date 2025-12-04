import pandas as pd
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
import re

# çizim stili için önce seaborn'u deniyorum, olmazsa ggplot'a düşüyorum
try:
   plt.style.use("seaborn-v0_8")
except OSError:
   plt.style.use("ggplot")

# kaza verilerini excel dosyasından alıyorum
df = pd.read_excel("kaza_adresli.xlsx")
# çalışacağım yıl aralığını burada tanımladım
years = list(range(2020, 2025))
# yıl sütununu tam sayıya çeviriyorum
df["Metai"] = df["Metai"].astype(int)

# adres metninden sokak ismini çekmek için fonksiyon
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

# her satır için sokak bilgisini yeni sütuna yazıyorum
df["Street"] = df["address"].apply(extract_street)

# klaipeda için en çok kaza olan sokakların yıllık trendini çıkaran fonksiyon
def get_top_street_trend_klaipeda(n_top=5):
   city_df = df[
       (df["Metai"].between(2020, 2024)) &
       (df["address"].str.contains("Klaipėda|Klaipeda", case=False, na=False))
   ].copy()

   # sokaklara göre toplam kaza sayılarını hesaplıyorum
   street_counts = (
       city_df.groupby("Street").size().sort_values(ascending=False)
   )
   # en çok kazaya sahip ilk n sokağın listesini alıyorum
   top_streets = street_counts.head(n_top).index.tolist()

   # sadece bu sokaklara ait satırları filtreliyorum
   top_df = city_df[city_df["Street"].isin(top_streets)]

   # yıl + sokak kırılımında tabloyu pivotluyorum
   trend_df = (
       top_df
       .groupby(["Metai", "Street"])
       .size()
       .unstack("Street")
       .reindex(years, fill_value=0)
   )
   return trend_df, top_streets

# bir şehrin top sokaklarını grafikte göstermek için genel fonksiyon
def plot_city_topN(trend_df, city_name, streets, filename):
   fig, ax = plt.subplots(figsize=(11, 6))
   # her sokak için kullanacağım renk listesini burada tutuyorum
   colors = ["red", "gold", "green", "royalblue", "purple", "darkorange"]

   # her sokağı ayrı bir çizgi olarak çiziyorum
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
       # nokta üzerine kaza sayısını yazıyorum
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

   # başlık ve eksen isimlerini burada ayarlıyorum
   ax.set_title(
       f"Annual Accidents on Top {len(streets)} Streets in {city_name} (2020–2024)",
       fontsize=16,
       fontweight="bold",
       pad=15
   )
   ax.set_xlabel("Year", fontsize=13)
   ax.set_ylabel("Number of accidents", fontsize=13)

   # x ekseninde doğrudan yıl aralığını kullanıyorum
   ax.set_xticks(years)
   ax.tick_params(axis="both", labelsize=11)

   # yatay grid ile okunabilirliği biraz artırıyorum
   ax.yaxis.grid(True, linestyle="--", linewidth=0.7, alpha=0.7)
   ax.set_axisbelow(True)

   # üst ve sağ çerçeveyi kapatıyorum, sade dursun
   for spine in ["top", "right"]:
       ax.spines[spine].set_visible(False)

   # en büyük değere göre y ekseni sınırını az biraz yukarıdan bırakıyorum
   max_val = trend_df.values.max()
   ax.set_ylim(0, max_val * 1.25 if max_val > 0 else 1)

   # legend'i grafiğin sağına taşıyorum
   ax.legend(
       title="City – Street",
       fontsize=10,
       title_fontsize=11,
       loc="upper left",
       bbox_to_anchor=(1.02, 1.0),
       borderaxespad=0.
   )

   # düzeni sıkılaştırıp grafiği dosyaya kaydediyorum
   fig.tight_layout()
   fig.savefig(filename, dpi=500, bbox_inches="tight")
   plt.show()

# önce klaipeda için en çok kazalı sokak trendini alıyorum
klaipeda_trend, klaipeda_streets = get_top_street_trend_klaipeda(n_top=5)

# sonra bu trendi çizdirip png olarak dışarıya kaydediyorum
plot_city_topN(
   klaipeda_trend,
   "Klaipėda",
   klaipeda_streets,
   "klaipeda_top5_streets_annual_accidents_2020_2024.png"
)
