import os
import geopandas as gpd
import rasterio
from rasterio.mask import mask
from shapely.ops import unary_union
import numpy as np
import pandas as pd
from shapely.geometry import box
from pathlib import Path

# =========================
# Path Settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
BUILTUP_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
WATER_DIR   = PARENT_DIR / "raw" / "water_polygons"
POP_DIR     = PARENT_DIR / "raw" / "population"
OUT_CSV     = PARENT_DIR / "processed" / "blue_exposure_index" / "blue_exposure_index_.csv"

BUFFER_DIST = 500  # meters
# =========================
# Utility Functions
# =========================
def fname(fp):
    return os.path.splitext(os.path.basename(fp))[0]

def normalize_water_name(name):
    return name.replace("_", " ").strip()

def calc_population(raster_fp, geom):
    """Calculate the sum of population within the given geometry"""
    with rasterio.open(raster_fp) as src:
        if not geom.intersects(box(*src.bounds)):
            return 0.0

        out_img, _ = mask(
            src,
            [geom],
            crop=True,
            filled=True,
            nodata=0
        )
        return float(np.nansum(out_img))

# =========================
# Build File Index
# =========================
builtup_files = {
    fname(f): os.path.join(BUILTUP_DIR, f)
    for f in os.listdir(BUILTUP_DIR)
    if f.endswith(".shp")
}

pop_files = {
    fname(f): os.path.join(POP_DIR, f)
    for f in os.listdir(POP_DIR)
    if f.endswith(".tif")
}

water_files = {
    normalize_water_name(fname(f)): os.path.join(WATER_DIR, f)
    for f in os.listdir(WATER_DIR)
    if f.endswith(".shp")
}

# =========================
# Main Loop
# =========================
results = []

for city, builtup_fp in builtup_files.items():

    if city not in pop_files or city not in water_files:
        print(f"⚠️ Missing data, skipping: {city}")
        continue

    print(f"▶ Processing: {city}")

    # -------- Built-up Area --------
    builtup = gpd.read_file(builtup_fp).to_crs("EPSG:4326")
    builtup_geom = unary_union(builtup.geometry)

    # -------- Water Bodies --------
    water = gpd.read_file(water_files[city]).to_crs("EPSG:4326")
    water_geom = unary_union(water.geometry)

    # -------- Water 500m Buffer (Requires Projection) --------
    water_proj = gpd.GeoSeries([water_geom], crs="EPSG:4326").to_crs("EPSG:3857")
    water_buffer_proj = water_proj.buffer(BUFFER_DIST)
    water_buffer = water_buffer_proj.to_crs("EPSG:4326").iloc[0]

    # -------- Intersection of Built-up Area and Buffer --------
    blue_buffer_geom = builtup_geom.intersection(water_buffer)

    # -------- Population Calculation --------
    total_pop = calc_population(pop_files[city], builtup_geom)

    if blue_buffer_geom.is_empty:
        blue_pop = 0.0
    else:
        blue_pop = calc_population(pop_files[city], blue_buffer_geom)

    blue_exposure_index = blue_pop / total_pop if total_pop > 0 else 0

    results.append({
        "city": city,
        "blue_exposure_index": blue_exposure_index
    })

# =========================
# Output
# =========================
df = pd.DataFrame(results)
df.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")

print("✅ 500m buffer Blue Exposure Index calculation finished:")
print(OUT_CSV)