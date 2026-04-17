# NOTE: For most Southeast Asian cities, residential land polygons are retrieved 
# using 'get_urban_residential_area_from_OSM1.py'; however, for some cities, 
# data only can be obtained via 'get_urban_residential_area_from_OSM2.py'.

import osmnx as ox
import geopandas as gpd
import os
import time
import re
import pandas as pd
from pathlib import Path
# ========================
# 0. City Selection Switch
# ========================

# Download Mode:
# "all"      -> Download all cities
# "selected" -> Only download cities in SELECTED_CITIES
DOWNLOAD_MODE = "selected"

# Only active when DOWNLOAD_MODE == "selected"
SELECTED_CITIES = [
    "Banda Aceh"
]

# Uniform processing to prevent whitespace/type issues
SELECTED_CITIES = {str(c).strip() for c in SELECTED_CITIES}


# ========================
# 1. Input / Output
# ========================
PARENT_DIR = Path("data") / "replication_geometric"
boundary_fp = PARENT_DIR / "processed" / "SEA_city_core.shp"
out_dir = PARENT_DIR / "raw" / "residential_polygons"

os.makedirs(out_dir, exist_ok=True)

boundary = gpd.read_file(boundary_fp).to_crs(epsg=4326)


# ========================
# 2. OSM Tags
# ========================
residential_tags = {
    "landuse": ["residential"],
    "place": ["neighbourhood", "suburb", "village"],
    "building": ["residential", "house", "apartments", "detached",
                 "semidetached_house", "terrace"]
}


# ========================
# 3. Safe Filename Function
# ========================
def safe_filename(name):
    """Convert city name to a safe filename."""
    name = str(name).strip()
    name = re.sub(r"[\\/:*?\"<>|]", "_", name)
    name = re.sub(r"\s+", "_", name)
    return name


# ========================
# 4. Batch Fetching + Cleaning + Saving
# ========================
for idx, row in boundary.iterrows():
    geom = row.geometry

    # ---- Basic Geometry Check ----
    if geom is None or geom.is_empty:
        continue
    if geom.geom_type not in ["Polygon", "MultiPolygon"]:
        continue

    city_raw = row.get("city")

    # ---- city Field Safety Check ----
    if pd.isna(city_raw):
        continue

    # ---- City Selection Logic ----
    if DOWNLOAD_MODE == "selected":
        if str(city_raw).strip() not in SELECTED_CITIES:
            continue

    city_name = safe_filename(city_raw)
    out_shp = out_dir / f"{city_name}.shp"

    # ---- Resume from Checkpoint ----
    if os.path.exists(out_shp):
        print(f"✓ Skip {city_name}")
        continue

    try:
        print(f"Fetching {city_name}")

        # ---- OSM Query ----
        gdf_city = ox.features_from_polygon(
            geom,
            tags=residential_tags
        )

        if gdf_city.empty:
            print("  - No residential features")
            continue

        # ---- Keep Polygons Only + Reset Index ----
        gdf_city = gdf_city[
            gdf_city.geometry.type.isin(["Polygon", "MultiPolygon"])
        ].reset_index(drop=True)

        if gdf_city.empty:
            print("  - No polygon features after filtering")
            continue

        # ---- Geometry Repair (Fix self-intersection) ----
        gdf_city["geometry"] = gdf_city.geometry.buffer(0)

        # ---- Clean Attributes (Keep geometry + city only) ----
        gdf_clean = gpd.GeoDataFrame(
            {"city": [city_raw] * len(gdf_city)},
            geometry=gdf_city.geometry,
            crs="EPSG:4326"
        )

        # ---- Save Output ----
        gdf_clean.to_file(out_shp)
        print(f"  ✓ Saved: {city_name}.shp")

        # ---- Rate Limiting ----
        time.sleep(2)

    except Exception as e:
        print(f"⚠️ Failed at {city_name}: {e}")
        continue