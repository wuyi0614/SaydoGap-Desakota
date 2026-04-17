import os
import numpy as np
import geopandas as gpd
import rasterio
from rasterio.mask import mask
from rasterio.warp import reproject, Resampling
from shapely.geometry import box
from scipy.ndimage import uniform_filter
import pandas as pd
from pathlib import Path

# =========================
# Path Settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
CITY_SHP_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
GURS_TIF = PARENT_DIR / "raw" / "global_urban_and_rural_settlement" / "GURS_SA_.tif"
LUCC_DIR = PARENT_DIR / "raw" / "land_use"
OUT_CSV = PARENT_DIR / "processed" / "desakota_index" / "Desakota_index_crop_only.csv"

# =========================
# Parameters
# =========================
BUFFER_DIST = 3000        # 3 km buffer
BUFFER_CRS = "EPSG:3857"
WINDOW = 9               # 9×9 spatial window
EPS = 1e-6

# =========================
# Resampling Function (Nearest Neighbor for LUCC as per original setup)
# =========================
def resample_to_match(src_array, src_transform, src_crs,
                      dst_shape, dst_transform, dst_crs,
                      dtype=np.uint8,
                      resampling=Resampling.nearest):
    """Resample source raster to match destination raster geometry"""
    dst = np.zeros(dst_shape, dtype=dtype)

    reproject(
        source=src_array,
        destination=dst,
        src_transform=src_transform,
        src_crs=src_crs,
        dst_transform=dst_transform,
        dst_crs=dst_crs,
        resampling=resampling
    )
    return dst


results = []
skipped = []

# =========================
# Open GURS Dataset
# =========================
with rasterio.open(GURS_TIF) as gurs_src:

    raster_extent = box(*gurs_src.bounds)
    pixel_area = abs(gurs_src.res[0] * gurs_src.res[1])

    for shp_name in os.listdir(CITY_SHP_DIR):

        if not shp_name.lower().endswith(".shp"):
            continue

        city = os.path.splitext(shp_name)[0]
        shp_path = os.path.join(CITY_SHP_DIR, shp_name)

        print(f"▶ Processing {city}")

        lucc_path = os.path.join(LUCC_DIR, f"{city}.tif")
        if not os.path.exists(lucc_path):
            skipped.append(city)
            continue

        city_gdf = gpd.read_file(shp_path)
        if city_gdf.empty:
            skipped.append(city)
            continue

        # =========================
        # CRS Transformation: WGS84 -> Metric -> Buffer -> WGS84
        # =========================
        city_proj = city_gdf.to_crs(BUFFER_CRS)
        geom = city_proj.geometry.unary_union.buffer(BUFFER_DIST)

        if not geom.is_valid:
            geom = geom.buffer(0)

        geom = gpd.GeoSeries([geom], crs=BUFFER_CRS).to_crs(gurs_src.crs)
        geom = [geom.iloc[0]]

        if not geom[0].intersects(raster_extent):
            skipped.append(city)
            continue

        # =========================
        # Mask GURS
        # =========================
        try:
            gurs, gurs_transform = mask(gurs_src, geom, crop=True, nodata=0)
        except ValueError:
            skipped.append(city)
            continue

        gurs = gurs[0]

        # =========================
        # Mask + Resample LUCC
        # =========================
        with rasterio.open(lucc_path) as lucc_src:
            lucc_raw, lucc_transform = mask(lucc_src, geom, crop=True, nodata=0)
            lucc_raw = lucc_raw[0]

            A = resample_to_match(
                lucc_raw,
                lucc_transform,
                lucc_src.crs,
                gurs.shape,
                gurs_transform,
                gurs_src.crs
            )

        # Binary Agricultural mask
        A = (A == 1).astype(np.uint8)

        # =========================
        # Pixel-level Classification (Agriculture priority)
        # =========================
        U = ((gurs == 1) & (A == 0)).astype(np.uint8)
        V = ((gurs == 2) & (A == 0)).astype(np.uint8)

        urban_area = U.sum() * pixel_area
        if urban_area == 0:
            results.append({
                "city": city,
                "Desakota_index": 0
            })
            continue

        # =========================
        # 1. Mixing Degree (Shannon Entropy)
        # =========================
        p_u = uniform_filter(U.astype(float), WINDOW)
        p_v = uniform_filter(V.astype(float), WINDOW)
        p_a = uniform_filter(A.astype(float), WINDOW)

        # Define Desakota zones where Urban coexists with Agri or Village
        mask_u_a = (p_u > 0) & (p_a > 0)
        mask_u_v_a = (p_u > 0) & (p_v > 0) & (p_a > 0)
        desakota_mask = mask_u_a | mask_u_v_a

        p_sum = p_u + p_v + p_a + EPS
        pu = p_u / p_sum
        pv = p_v / p_sum
        pa = p_a / p_sum

        H = -(pu * np.log(pu + EPS) +
              pv * np.log(pv + EPS) +
              pa * np.log(pa + EPS))

        H_norm = H / np.log(3)

        desakota_mix_area = np.sum(
            desakota_mask * H_norm
        ) * pixel_area

        # =========================
        # 2. Fragmentation Degree (Local Class Variance)
        # =========================
        C = np.zeros_like(U, dtype=np.uint8)
        C[U == 1] = 1
        C[V == 1] = 2
        C[A == 1] = 3

        C_mean = uniform_filter(C.astype(float), WINDOW)
        C_sq_mean = uniform_filter((C.astype(float)) ** 2, WINDOW)

        # Local variance as a proxy for fragmentation
        frag = C_sq_mean - C_mean ** 2
        frag_norm = frag / (frag.max() + EPS)

        desakota_frag_area = np.sum(
            desakota_mask * H_norm * frag_norm
        ) * pixel_area

        # =========================
        # 3. Aggregate Desakota Raw Value
        # =========================
        desakota_raw = 0.5 * desakota_mix_area + 0.5 * desakota_frag_area

        results.append({
            "city": city,
            "Desakota_raw": float(desakota_raw)
        })

# =========================
# Normalization (Final Desakota_index)
# =========================
df = pd.DataFrame(results)

df["Desakota_Index_CropOnly"] = (
    df["Desakota_raw"] - df["Desakota_raw"].min()
) / (
    df["Desakota_raw"].max() - df["Desakota_raw"].min() + EPS
)

df = df[["city", "Desakota_Index_CropOnly"]]

df.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")

print("\n✔ Finished")
print("Skipped cities:", skipped)
print("Output saved to:", OUT_CSV)