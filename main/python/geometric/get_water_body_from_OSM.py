import osmnx as ox
import geopandas as gpd
import os
import time
import re
import pandas as pd
from pathlib import Path

# =====================================================
# 0. City Selection Switch
# =====================================================

# "all"      -> Download all cities
# "selected" -> Only download cities in SELECTED_CITIES
DOWNLOAD_MODE = "selected"

SELECTED_CITIES = [
    "Agusan del Norte", "Banjarnegara", "Basilan", "Bohol", "Compostela Valley", "Cotabato (North Cotabato)", "Ilocos Norte", "Ilocos Sur",
    "Kalinga", "N. Sembilan", "Oriental Mindoro", "Putrajaya", "Sarangani", "Sultan Kudarat", "Sulu", "Tawi-Tawi"
]

SELECTED_CITIES = {str(c).strip() for c in SELECTED_CITIES}


# =====================================================
# 1. Input / Output
# =====================================================
PARENT_DIR = Path("data") / "replication_geometric"
boundary_fp = PARENT_DIR / "raw" / "administrative_boundaries _SEA_cities" / "sea-city-with-coordinates.shp"
out_dir = PARENT_DIR / "raw" / "water_polygons"

os.makedirs(out_dir, exist_ok=True)

boundary = gpd.read_file(boundary_fp).to_crs(epsg=4326)


# =====================================================
# 2. OSM Green Space & Water Tags (Comprehensive)
# =====================================================

park_tags = {
    "leisure": [
        "park",
        "garden",
        "recreation_ground",
        "nature_reserve",
        "pitch"
    ],
    "landuse": [
        "grass",
        "village_green",
        "forest"
    ],
    "natural": [
        "wood"
    ]
}

water_tags = {
    "natural": [
        "water"
    ],
    "water": [
        "lake",
        "reservoir",
        "pond",
        "river",
        "canal",
        "basin"
    ],
    "landuse": [
        "reservoir"
    ],
    "waterway": [
        "riverbank",
        "canal",
        "ditch"
    ]
}


# =====================================================
# 3. Safe Filename Function
# =====================================================

def safe_filename(name):
    name = str(name).strip()
    name = re.sub(r"[\\/:*?\"<>|]", "_", name)
    name = re.sub(r"\s+", "_", name)
    return name


# =====================================================
# 4. Batch Fetching + Cleaning + Saving
# =====================================================

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
    out_shp = os.path.join(out_dir, f"{city_name}.shp")

    # ---- Resume from Checkpoint ----
    if os.path.exists(out_shp):
        print(f"✓ Skip {city_name}")
        continue

    try:
        print(f"Fetching {city_name}")

        # -----------------------------
        # OSM Query
        # -----------------------------
        gdf_city = ox.features_from_polygon(
            geom,
            tags=water_tags
        )

        if gdf_city.empty:
            print("  - No water features")
            continue

        # -----------------------------
        # Keep Polygon Features Only
        # -----------------------------
        gdf_city = gdf_city[
            gdf_city.geometry.type.isin(["Polygon", "MultiPolygon"])
        ].reset_index(drop=True)

        if gdf_city.empty:
            print("  - No polygon features after filtering")
            continue

        # -----------------------------
        # Filter Out Private Features
        # -----------------------------
        if "access" in gdf_city.columns:
            gdf_city = gdf_city[
                ~gdf_city["access"].isin(["private", "no"])
            ]

        if gdf_city.empty:
            print("  - All features removed by access filter")
            continue

        # -----------------------------
        # Geometry Repair
        # -----------------------------
        gdf_city["geometry"] = gdf_city.geometry.buffer(0)

        # -----------------------------
        # Area Filter (Noise Removal)
        # -----------------------------
        gdf_m = gdf_city.to_crs(epsg=3857)
        gdf_m["area_m2"] = gdf_m.geometry.area

        gdf_m = gdf_m[gdf_m["area_m2"] >= 2000]

        if gdf_m.empty:
            print("  - All features removed by area filter")
            continue

        gdf_city = gdf_m.to_crs(epsg=4326)

        # -----------------------------
        # Simplify Fields for Standard AOI Output
        # -----------------------------
        gdf_clean = gpd.GeoDataFrame(
            {
                "city": [city_raw] * len(gdf_city),
                "source": ["OpenStreetMap"] * len(gdf_city),
                "aoi_type": ["urban_water"] * len(gdf_city)
            },
            geometry=gdf_city.geometry,
            crs="EPSG:4326"
        )

        # -----------------------------
        # Save Output
        # -----------------------------
        gdf_clean.to_file(out_shp)
        print(f"  ✓ Saved: {city_name}.shp")

        # Rate Limiting
        time.sleep(2)

    except Exception as e:
        print(f"⚠️ Failed at {city_name}: {e}")
        continue