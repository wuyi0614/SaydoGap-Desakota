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
# 0. OSMnx Parameter Settings (Stable State)
# ========================
ox.settings.timeout = 300
ox.settings.max_retries = 10
ox.settings.overpass_rate_limit = True

DOWNLOAD_MODE = "selected"   # "all" or "selected"

SELECTED_CITIES = ["Sarangani"]
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
# 2. OSM Tag Settings
# ========================

# —— Semantic Residential Areas (Planning context)
semantic_residential_tags = {
    "landuse": ["residential"],
    "place": ["neighbourhood", "suburb", "village"],
    "building": [
        "residential", "house", "apartments",
        "detached", "semidetached_house", "terrace"
    ]
}

# —— Residential Buildings (Note: specific tags only, no building=True)
residential_building_tags = {
    "building": [
        "house",
        "apartments",
        "residential",
        "detached",
        "semidetached_house",
        "terrace"
    ]
}

# ========================
# 3. Safe Filename Function
# ========================
def safe_filename(name):
    name = str(name).strip()
    name = re.sub(r"[\\/:*?\"<>|]", "_", name)
    name = re.sub(r"\s+", "_", name)
    return name

# ========================
# 4. Batch Fetching + Merging + Saving
# ========================
for idx, row in boundary.iterrows():

    geom = row.geometry
    if geom is None or geom.is_empty:
        continue
    if geom.geom_type not in ["Polygon", "MultiPolygon"]:
        continue

    city_raw = row.get("city")
    if pd.isna(city_raw):
        continue

    if DOWNLOAD_MODE == "selected":
        if str(city_raw).strip() not in SELECTED_CITIES:
            continue

    city_name = safe_filename(city_raw)
    out_shp = out_dir / f"{city_name}.shp"

    if out_shp.exists():
        print(f"✓ Skip {city_name}")
        continue

    try:
        print(f"Fetching {city_name}")

        # ========================
        # 4.1 Semantic Residential Areas
        # ========================
        gdf_sem = ox.features_from_polygon(
            geom,
            tags=semantic_residential_tags
        )

        # ========================
        # 4.2 Residential Buildings
        # ========================
        gdf_bld = ox.features_from_polygon(
            geom,
            tags=residential_building_tags
        )

        # ========================
        # 4.3 Merging
        # ========================
        gdf_city = pd.concat([gdf_sem, gdf_bld], ignore_index=True)

        if gdf_city.empty:
            print("  - No residential features")
            continue

        # ========================
        # 4.4 Keep Polygon Features Only
        # ========================
        gdf_city = gdf_city[
            gdf_city.geometry.type.isin(["Polygon", "MultiPolygon"])
        ].reset_index(drop=True)

        if gdf_city.empty:
            print("  - No polygon features after filtering")
            continue

        # ========================
        # 4.5 Geometry Repair
        # ========================
        gdf_city["geometry"] = gdf_city.geometry.buffer(0)
        gdf_city = gdf_city[~gdf_city.geometry.is_empty]

        if gdf_city.empty:
            print("  - Empty after geometry fixing")
            continue

        # ========================
        # 4.6 Simplify Attributes
        # ========================
        gdf_clean = gpd.GeoDataFrame(
            {"city": [city_raw] * len(gdf_city)},
            geometry=gdf_city.geometry,
            crs="EPSG:4326"
        )

        # ========================
        # 4.7 Save Output
        # ========================
        gdf_clean.to_file(out_shp)
        print(f"  ✓ Saved: {city_name}.shp")

        time.sleep(2)

    except Exception as e:
        print(f"⚠️ Failed at {city_name}: {e}")
        continue