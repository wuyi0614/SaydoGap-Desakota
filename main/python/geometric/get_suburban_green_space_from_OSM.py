import osmnx as ox
import geopandas as gpd
import os
import time
import re
import pandas as pd
from pyproj import CRS
from pathlib import Path

# ========================
# 0. City Selection Switch
# ========================

DOWNLOAD_MODE = "all"
# "selected" -> only process SELECTED_CITIES
# "all"      -> process all cities in sequence

SELECTED_CITIES = [
    "Banda Aceh"
]

SELECTED_CITIES = {str(c).strip() for c in SELECTED_CITIES}


# ========================
# 1. Input / Output
# ========================
PARENT_DIR = Path("data") / "replication_geometric"
boundary_fp = PARENT_DIR / "processed" / "SEA_city_core.shp"
out_dir = PARENT_DIR / "raw" / "suburban_green_space"

os.makedirs(out_dir, exist_ok=True)

boundary = gpd.read_file(boundary_fp).to_crs(epsg=4326)


# ========================
# 2. OSM Green Space Tags
# ========================

green_tags = {
    "leisure": ["park", "nature_reserve", "garden", "recreation_ground"],
    "landuse": ["forest", "grass", "recreation_ground", "village_green"],
    "tourism": ["attraction", "picnic_site", "theme_park", "viewpoint"],
    "boundary": ["protected_area"]
}


# ========================
# 3. Automatic UTM Projection Function
# ========================

def get_utm_crs(geom):
    lon = geom.centroid.x
    lat = geom.centroid.y
    zone = int((lon + 180) / 6) + 1
    south = "+south" if lat < 0 else ""

    return CRS.from_proj4(
        f"+proj=utm +zone={zone} {south} "
        "+datum=WGS84 +units=m +no_defs"
    )


# ========================
# 4. Safe Filename Function
# ========================

def safe_filename(name):
    name = str(name).strip()
    name = re.sub(r"[\\/:*?\"<>|]", "_", name)
    name = re.sub(r"\s+", "_", name)
    return name


# ========================
# 5. OSM Settings
# ========================

ox.settings.use_cache = True
ox.settings.timeout = 300

print(f"Download mode: {DOWNLOAD_MODE}")


# ========================
# 6. Batch Download
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

    city_str = str(city_raw).strip()

    # -------- City Selection Logic --------
    if DOWNLOAD_MODE == "selected":
        if city_str not in SELECTED_CITIES:
            continue

    elif DOWNLOAD_MODE == "all":
        pass

    else:
        raise ValueError(
            'DOWNLOAD_MODE must be "selected" or "all"'
        )

    city_name = safe_filename(city_raw)
    out_shp = os.path.join(out_dir, f"{city_name}.shp")

    if os.path.exists(out_shp):
        print(f"✓ Skip {city_name}")
        continue

    try:
        print(f"Fetching green space: {city_name}")

        # -------- Automatic UTM Projection --------
        utm_crs = get_utm_crs(geom)

        geom_proj = (
            gpd.GeoSeries([geom], crs=4326)
            .to_crs(utm_crs)
        )

        # -------- 5km buffer --------
        buffer_geom = geom_proj.buffer(5000)

        buffer_wgs = (
            gpd.GeoSeries(buffer_geom, crs=utm_crs)
            .to_crs(4326)
            .iloc[0]
        )

        # Simplify polygon to avoid OSM timeout
        buffer_wgs = buffer_wgs.simplify(0.001)

        # -------- OSM Fetching --------
        gdf_city = ox.features_from_polygon(
            buffer_wgs,
            tags=green_tags
        )

        if gdf_city.empty:
            print("  - No green space")
            continue

        # -------- Keep Polygon Features --------
        gdf_city = gdf_city[
            gdf_city.geometry.type.isin(["Polygon", "MultiPolygon"])
        ].reset_index(drop=True)

        if gdf_city.empty:
            print("  - No polygon features")
            continue

        # -------- Geometry Repair --------
        gdf_city["geometry"] = gdf_city.geometry.buffer(0)

        # -------- Clean Attributes --------
        gdf_clean = gpd.GeoDataFrame(
            {"city": [city_raw] * len(gdf_city)},
            geometry=gdf_city.geometry,
            crs="EPSG:4326"
        )

        # -------- Save --------
        gdf_clean.to_file(out_shp)

        print(f"  ✓ Saved: {city_name}.shp")

        # Prevent OSM rate limiting
        time.sleep(3)

    except Exception as e:
        print(f"⚠️ Failed at {city_name}: {e}")
        continue