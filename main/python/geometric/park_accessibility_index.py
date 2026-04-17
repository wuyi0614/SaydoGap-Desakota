import os
import geopandas as gpd
import pandas as pd
from shapely.ops import unary_union
from pyproj import CRS
from pathlib import Path

# =========================
# Path Settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
RES_DIR = PARENT_DIR / "raw" / "residential_polygons"
PARK_DIR = PARENT_DIR / "raw" / "park_polygons"
OUT_CSV = PARENT_DIR / "processed" / "park_accessibility_index" / "park_accessibility_results.csv"

# Distance thresholds for accessibility analysis (meters)
DIST_THRESHOLDS = [300, 500]

# =========================
# Utility Functions
# =========================
def get_city_name(fp):
    return Path(fp).stem

def get_utm_crs(gdf):
    """Automatically determine the UTM CRS based on the centroid of the geometry"""
    lon, lat = gdf.geometry.unary_union.centroid.coords[0]
    zone = int((lon + 180) / 6) + 1
    # EPSG 326xx for North, 327xx for South
    return CRS.from_epsg(32600 + zone if lat >= 0 else 32700 + zone)

def fix_park_geometry(gdf):
    """Clean and repair park geometries using zero-buffer"""
    gdf["geometry"] = gdf.geometry.buffer(0)
    gdf = gdf[~gdf.geometry.is_empty]
    return gdf

# =========================
# Build File Lists
# =========================
res_files = {
    get_city_name(f): os.path.join(RES_DIR, f)
    for f in os.listdir(RES_DIR) if f.endswith(".shp")
}

park_files = {
    get_city_name(f): os.path.join(PARK_DIR, f)
    for f in os.listdir(PARK_DIR) if f.endswith(".shp")
}

# Only analyze cities where both Residential and Park datasets are present
cities = sorted(set(res_files) & set(park_files))
print(f"✅ Matched cities: {len(cities)}")

# =========================
# Main Loop
# =========================
results = []

for city in cities:
    print(f"▶ Processing {city}")
    try:
        res = gpd.read_file(res_files[city])
        park = gpd.read_file(park_files[city])

        # ---- Projection ----
        # Transform all datasets to the local UTM CRS for accurate distance measurement
        utm_crs = get_utm_crs(res)
        res = res.to_crs(utm_crs)
        park = park.to_crs(utm_crs)

        # ---- Park Geometry Normalization ----
        park = fix_park_geometry(park)
        park_union = unary_union(park.geometry)

        # ---- Residential Areas to Centroids ----
        # Calculate centroids to represent residential demand points
        res["centroid"] = res.geometry.centroid
        res_pts = res.set_geometry("centroid")

        # ---- Distance Calculation ----
        # Calculate the Euclidean distance from each residential point to the nearest park
        res_pts["dist_park"] = res_pts.geometry.apply(
            lambda p: p.distance(park_union)
        )

        # ---- City Indicators ----
        row = {
            "city": city,
            "mean_dist_m": round(res_pts["dist_park"].mean(), 2),
            "n_residential_units": len(res_pts)
        }

        # Calculate the percentage of residential units within specified thresholds
        for d in DIST_THRESHOLDS:
            row[f"Park Accessibility_within_{d}m"] = round(
                (res_pts["dist_park"] <= d).mean() * 100, 2
            )
        
        results.append(row)

    except Exception as e:
        print(f"⚠️ Failed to process {city}: {e}")

# =========================
# Output Results
# =========================
df = pd.DataFrame(results)
df.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")

print("✅ Processing finished. Results saved to:")
print(OUT_CSV)