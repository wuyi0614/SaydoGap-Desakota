import os
import geopandas as gpd
import rasterio
from rasterio.mask import mask
import numpy as np
import pandas as pd
from shapely.geometry import mapping
from pathlib import Path
# ===============================
# 1. Parameter Section (Main area to modify)
# ===============================
PARENT_DIR = Path("data") / "replication_geometric"
CITY_SHP_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
LUCC_TIF_DIR = PARENT_DIR / "raw" / "land_use"
OUT_CSV = PARENT_DIR / "processed" / "cropland_ratio" / "cropland_ratio.csv"
BUFFER_DISTANCE = 5000 # Buffer distance (meters), e.g. 1000 / 3000 / 5000
TARGET_CRS = "EPSG:3857" # Projected CRS with meter as unit

# ===============================
# 2. Tool Functions
# ===============================
def calc_farmland_area(buffer_geom, tif_path):
    """
    Calculate farmland area within the buffer zone (pixel value = 1)
    """
    with rasterio.open(tif_path) as src:
        buffer_geom = buffer_geom.to_crs(src.crs)
        out_image, out_transform = mask(
            src,
            [mapping(buffer_geom.geometry.iloc[0])],
            crop=True,
            all_touched=True
        )
        data = out_image[0]
        data = data[data != src.nodata]
        # Number of farmland pixels (value = 1)
        farmland_pixels = np.sum(data == 1)
        # Pixel area (m²)
        pixel_area = abs(src.transform.a * src.transform.e)
        return farmland_pixels


# ===============================
# 3. Main Program
# ===============================
results = []
for shp_name in os.listdir(CITY_SHP_DIR):
    if not shp_name.endswith(".shp"):
        continue
    city_name = os.path.splitext(shp_name)[0]
    shp_path = os.path.join(CITY_SHP_DIR, shp_name)
    tif_path = os.path.join(LUCC_TIF_DIR, city_name + ".tif")
    if not os.path.exists(tif_path):
        print(f"⚠ Missing LUCC tif: {city_name}")
        continue
    print(f"Processing: {city_name}")
    # Read built-up area
    city = gpd.read_file(shp_path)
    city = city.to_crs(TARGET_CRS)
    # Merge into single geometry (to avoid MultiPolygon)
    city_geom = city.dissolve()
    # Calculate built-up area
    builtup_area = city_geom.geometry.area.iloc[0]
    # Generate buffer zone
    buffer_geom = city_geom.copy()
    buffer_geom["geometry"] = buffer_geom.geometry.buffer(BUFFER_DISTANCE)
    buffer_area = buffer_geom.geometry.area.iloc[0]
    # Calculate farmland area within buffer zone
    farmland_area = calc_farmland_area(buffer_geom, tif_path)
    results.append({
        "city": city_name,
        "cropland_ratio": farmland_area / builtup_area
    })

# ===============================
# 4. Output Results
# ===============================
df = pd.DataFrame(results)
df.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")
print("✅ All processing completed, results saved to:")
print(OUT_CSV)