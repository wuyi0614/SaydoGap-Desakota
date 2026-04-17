import os
import geopandas as gpd
import rasterio
from rasterio.mask import mask
from shapely.ops import unary_union, polygonize
import pandas as pd
import numpy as np
from pathlib import Path

# =========================
# Path Settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
BUILTUP_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
PARK_DIR = PARENT_DIR / "raw" / "park_polygons"
POP_DIR = PARENT_DIR / "raw" / "population"
OUT_CSV = PARENT_DIR / "processed" / "per_capita_park _and_park_proportion" / "urban_park_indicators.csv"

# Projection for area calculation (meters)
AREA_CRS = "EPSG:3857"

# =========================
# Helper Functions
# =========================
def filename_no_ext(fp):
    return os.path.splitext(os.path.basename(fp))[0]

def park_name_normalize(name):
    return name.replace("_", " ").strip()

def fix_park_geometry(gdf):
    """Handle polygons and closed linestrings for valid geometry"""
    polys = []

    for geom in gdf.geometry:
        if geom is None:
            continue
        if geom.geom_type in ["Polygon", "MultiPolygon"]:
            polys.append(geom)
        elif geom.geom_type == "LineString" and geom.is_ring:
            polys.extend(list(polygonize(geom)))

    if len(polys) == 0:
        return None
    return unary_union(polys)

def calc_population(raster_path, geom):
    """Calculate total population within the provided geometry"""
    with rasterio.open(raster_path) as src:
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
    filename_no_ext(f): os.path.join(BUILTUP_DIR, f)
    for f in os.listdir(BUILTUP_DIR)
    if f.endswith(".shp")
}

pop_files = {
    filename_no_ext(f): os.path.join(POP_DIR, f)
    for f in os.listdir(POP_DIR)
    if f.endswith(".tif")
}

park_files = {
    park_name_normalize(filename_no_ext(f)): os.path.join(PARK_DIR, f)
    for f in os.listdir(PARK_DIR)
    if f.endswith(".shp")
}

# =========================
# Main Loop
# =========================
results = []

for city, builtup_fp in builtup_files.items():

    if city not in pop_files or city not in park_files:
        print(f"⚠️ Missing data, skipping: {city}")
        continue

    print(f"Processing: {city}")

    # -------- Built-up Area --------
    builtup = gpd.read_file(builtup_fp)
    builtup = builtup.to_crs(AREA_CRS)
    builtup_geom = unary_union(builtup.geometry)
    builtup_area = builtup_geom.area  # In square meters

    # -------- Parks --------
    parks = gpd.read_file(park_files[city])
    parks = parks.to_crs(AREA_CRS)
    park_geom = fix_park_geometry(parks)

    if park_geom is None:
        park_area = 0.0
    else:
        # Calculate intersection within city limits
        park_in_city = park_geom.intersection(builtup_geom)
        park_area = park_in_city.area

    park_ratio = park_area / builtup_area if builtup_area > 0 else 0

    # -------- Population --------
    # Population raster usually requires WGS84 (EPSG:4326)
    builtup_wgs84 = gpd.GeoSeries([builtup_geom], crs=AREA_CRS).to_crs("EPSG:4326").iloc[0]
    population = calc_population(pop_files[city], builtup_wgs84)

    per_capita_park = park_area / population if population > 0 else 0

    # -------- Save Results --------
    results.append({
        "city": city,
        "Park Proportion": park_ratio,
        "Per Capita Park": per_capita_park
    })

# =========================
# Output
# =========================
df = pd.DataFrame(results)
df.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")

print("✅ Calculation finished. Results saved to:", OUT_CSV)