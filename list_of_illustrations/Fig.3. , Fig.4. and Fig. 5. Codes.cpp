import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import geopandas as gpd
import contextily as ctx
from pathlib import Path

# temel ayarları burada tutuyorum
EXCEL_PATH = "2020-2024m_EI-duomenys_viesinama.xlsx"
YEAR_TARGET = 2024
OUTPUT_DIR = Path("outputs_points_2024")
OUTPUT_DIR.mkdir(exist_ok=True)

# exceldeki kolon adlarını böyle sabitledim
COL_YEAR = "Metai"
COL_CITY_RAW = "Administracinis teritorinis vienetas"
# epsg:3346'da platuma = x, ilguma = y
COL_X = "Platuma"
COL_Y = "Ilguma"

# şehir isimlerini sadeleştirmek için küçük fonksiyon
def normalize_city(name: str):
   t = str(name).lower()
   if "vilnius" in t or "vilniaus" in t:
       return "Vilnius"
   if "kaunas" in t or "kauno" in t:
       return "Kaunas"
   if "klaip" in t:
       return "Klaipėda"
   return None

# her şehir için kullanacağım pencere yarıçapı (km)
CITY_WINDOW_KM = {"Kaunas": 25, "Vilnius": 30, "Klaipėda": 20}

# km'yi metreye çeviriyorum
def km_to_m(km: float) -> float:
   return float(km) * 1000.0

# şehir yarıçapına göre kabaca zoom seviyesi seçiyorum
def suggest_zoom(radius_km: float) -> int:
   """Şehir yarıçapına göre güvenli zoom önerisi (0–20)."""
   if radius_km <= 8:   return 15
   if radius_km <= 12:  return 14
   if radius_km <= 20:  return 13
   if radius_km <= 30:  return 12
   return 11

# veriyi excelden çekip temel temizliği yapıyorum
df = pd.read_excel(EXCEL_PATH)
df = df[[COL_YEAR, COL_X, COL_Y, COL_CITY_RAW]].copy()
for c in [COL_YEAR, COL_X, COL_Y]:
   df[c] = pd.to_numeric(df[c], errors="coerce")

# sadece hedef yılı bırakıyorum
df = df[(df[COL_YEAR] == YEAR_TARGET)]
df = df.dropna(subset=[COL_X, COL_Y])
df["City"] = df[COL_CITY_RAW].map(normalize_city)

# üç büyük şehre filtreliyorum
TARGET_CITIES = ["Kaunas", "Vilnius", "Klaipėda"]
df = df[df["City"].isin(TARGET_CITIES)]

# noktalardan geodataframe oluşturup 3346'dan 3857'ye çeviriyorum
gdf_3346 = gpd.GeoDataFrame(
   df, geometry=gpd.points_from_xy(df[COL_X], df[COL_Y]), crs="EPSG:3346"
)
gdf = gdf_3346.to_crs(3857)

# şehir merkezine göre sıkı bir alt küme almak için
def tight_city_subset(sub_3857: gpd.GeoDataFrame, city: str) -> gpd.GeoDataFrame:
   if sub_3857.empty:
       return sub_3857
   x = sub_3857.geometry.x.to_numpy()
   y = sub_3857.geometry.y.to_numpy()
   cx, cy = np.median(x), np.median(y)
   dist = np.hypot(x - cx, y - cy)

   if city in CITY_WINDOW_KM and CITY_WINDOW_KM[city] is not None:
       r = km_to_m(CITY_WINDOW_KM[city])
   else:
       r = np.quantile(dist, 0.92) * 1.10
       if not np.isfinite(r) or r <= 0:
           r = 15000.0

   mask = dist <= r
   sub = sub_3857[mask].copy()
   if len(sub) < 30 and len(sub_3857) >= 30:
       r *= 1.5
       mask = dist <= r
       sub = sub_3857[mask].copy()
   return sub

# harita sınırlarına biraz boşluk ekleyen yardımcı
def bounds_with_padding(gdf_in: gpd.GeoDataFrame, pad_ratio=0.06):
   xmin, ymin, xmax, ymax = gdf_in.total_bounds
   pad_x = (xmax - xmin) * pad_ratio
   pad_y = (ymax - ymin) * pad_ratio
   return (xmin - pad_x, ymin - pad_y, xmax + pad_x, ymax + pad_y)

# tek şehir için nokta haritası üreten fonksiyon
def make_city_points_2024(gdf_all: gpd.GeoDataFrame, city: str,
                         marker_size=20, edge_width=1.0, alpha=0.98):
   sub = gdf_all[gdf_all["City"] == city]
   if sub.empty:
       print(f"[WARN] No data for {city}")
       return

   sub = tight_city_subset(sub, city)
   if sub.empty:
       print(f"[WARN] After centric cropping, no data for {city}")
       return

   xmin, ymin, xmax, ymax = bounds_with_padding(sub, pad_ratio=0.06)

   fig, ax = plt.subplots(figsize=(10, 10))

   # önce eksen limitlerini ayarlıyorum
   ax.set_xlim([xmin, xmax])
   ax.set_ylim([ymin, ymax])

   # sonra altlık haritayı eklemeyi deniyorum
   try:
       rad_km = CITY_WINDOW_KM.get(city, 20)
       z = suggest_zoom(rad_km)
       ctx.add_basemap(
           ax,
           crs="EPSG:3857",
           source=ctx.providers.CartoDB.Positron,
           zoom=z,
           reset_extent=False
       )
   except Exception as e:
       print(f"[INFO] Basemap eklenemedi: {e}. Altlık olmadan devam.")

   # kaza noktalarını siyah dolu beyaz kenarlıkla çiziyorum
   sub.plot(
       ax=ax,
       markersize=marker_size,
       color="k",
       alpha=alpha,
       edgecolor="white",
       linewidth=edge_width,
       zorder=5,
   )

   ax.set_title(f"{city} — Accident Points ({YEAR_TARGET})", pad=12, fontsize=14)
   ax.set_xlabel("X (m) — EPSG:3857")
   ax.set_ylabel("Y (m) — EPSG:3857")
   ax.grid(alpha=0.15, linewidth=0.5, zorder=3)

   out_path = OUTPUT_DIR / f"{city}_points_{YEAR_TARGET}.png"
   plt.tight_layout()
   plt.savefig(out_path, dpi=300)
   plt.close(fig)
   print(f"[OK] Saved: {out_path}")

# hedef şehirler için tek tek harita üretiyorum
for c in TARGET_CITIES:
   make_city_points_2024(gdf, c, marker_size=22, edge_width=1.1, alpha=0.98)

print("\nDone. PNG dosyaları 'outputs_points_2024/' klasöründe.")
