import pandas as pd
import numpy as np
import ast
import matplotlib

# ekranda açmadan sadece dosyaya kaydedeyim diye agg kullanıyorum
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sklearn.cluster import DBSCAN

import geopandas as gpd
from shapely.geometry import Point
import contextily as ctx


def main():
    # csv dosyasını buradan içeri alıyorum
    csv_path = "k_k_v_accidents_data_lithuanian.csv"
    df = pd.read_csv(csv_path, encoding="utf-8")

    # sadece vilnius satırlarını filtreliyorum
    df_vilnius = df[df["City"].str.contains("Vilnius", case=False, na=False)].copy()

    if df_vilnius.empty:
        print("Uyarı: 'City' sütununda Vilnius bulunamadı. Lütfen CSV'yi kontrol et.")
        return

    # vilnius için coordinate_tuple içindeki tüm noktaları tek listeye açıyorum
    all_points = []

    for _, row in df_vilnius.iterrows():
        coord_str = row.get("Coordinate_Tuple")
        if pd.isna(coord_str):
            continue

        try:
            coords = ast.literal_eval(coord_str)
        except Exception:
            continue

        city = row.get("City", "")
        street = row.get("Street", "")

        for lat, lon in coords:
            all_points.append({
                "City": city,
                "Street": street,
                "lat": float(lat),
                "lon": float(lon),
            })

    if not all_points:
        print("Uyarı: Vilnius için kaza noktası çıkarılamadı.")
        return

    points_df = pd.DataFrame(all_points)
    print(f"Vilnius için toplam kaza noktası sayısı: {len(points_df)}")

    # enlem boylamdan geodataframe oluşturup epsg:4326 olarak ayarlıyorum
    gdf = gpd.GeoDataFrame(
        points_df,
        geometry=[Point(lon, lat) for lat, lon in zip(points_df["lat"], points_df["lon"])],
        crs="EPSG:4326"
    )

    # harita ve dbscan için web mercator (3857) sistemine çeviriyorum
    gdf_3857 = gdf.to_crs(epsg=3857)

    # dbscan girişi için x ve y koordinatlarını metre cinsinden alıyorum
    X = np.column_stack([gdf_3857.geometry.x.values, gdf_3857.geometry.y.values])

    # vilnius içinde dbscan ile küme analizi yapıyorum
    EPS_METERS = 600.0   # küme yarıçapı yaklaşık 600 m
    MIN_SAMPLES = 3      # en az 3 nokta olursa küme sayıyorum

    dbscan = DBSCAN(eps=EPS_METERS, min_samples=MIN_SAMPLES)
    labels = dbscan.fit_predict(X)
    gdf_3857["cluster"] = labels

    unique_labels = np.unique(labels)
    n_clusters = np.sum(unique_labels != -1)
    print(f"Vilnius için bulunan küme sayısı (noise hariç): {n_clusters}")

    # vilnius şehir merkezine göre küçük bir pencere belirliyorum
    center_lon, center_lat = 25.2797, 54.6872
    center_point = gpd.GeoSeries(
        [Point(center_lon, center_lat)],
        crs="EPSG:4326"
    ).to_crs(epsg=3857)[0]

    cx, cy = center_point.x, center_point.y

    # merkez etrafında yaklaşık 6 km yarıçapında alan bırakıyorum
    buffer_m = 6000
    x_min, x_max = cx - buffer_m, cx + buffer_m
    y_min, y_max = cy - buffer_m, cy + buffer_m

    # haritayı çizmek için figür ve eksen açıyorum
    fig, ax = plt.subplots(figsize=(7, 8))

    # önce harita sınırlarını ayarlıyorum
    ax.set_xlim(x_min, x_max)
    ax.set_ylim(y_min, y_max)
    ctx.add_basemap(
        ax,
        source=ctx.providers.OpenStreetMap.Mapnik,
        crs="EPSG:3857",
        alpha=0.4
    )

    # kümeye girmeyen noktaları küçük gri olarak çiziyorum
    noise_mask = (gdf_3857["cluster"] == -1)
    gdf_3857.loc[noise_mask].plot(
        ax=ax,
        markersize=8,
        color="lightgray",
        alpha=0.5,
        linewidth=0
    )

    # küme içindeki noktaları daha büyük kırmızı ile işaretliyorum
    cluster_mask = (gdf_3857["cluster"] != -1)
    gdf_3857.loc[cluster_mask].plot(
        ax=ax,
        markersize=26,
        color="red",
        alpha=0.9,
        linewidth=0
    )

    # eksenleri kapatıyorum, sadece harita kalsın
    ax.set_axis_off()

    # başlığı burada veriyorum
    ax.set_title(
        "DBSCAN spatial clustering of accident points in central Vilnius",
        fontsize=11
    )

    plt.tight_layout()

    # sonucu tez için yüksek çözünürlüklü png olarak kaydediyorum
    output_path = "figure_dbscan_vilnius_central.png"
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    print(f"Şekil başarıyla kaydedildi: {output_path}")


if __name__ == "__main__":
    main()
