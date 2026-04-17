import os
import geopandas as gpd
import pandas as pd
import numpy as np
from shapely.geometry import Polygon
from pyproj import CRS
from scipy.spatial import distance_matrix
from pathlib import Path

# =========================
# Path Settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
PARK_DIR = PARENT_DIR / "raw" / "park_polygons"
CITY_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
OUT_CSV = PARENT_DIR / "processed" / "patch_density_largest_patch_index_patch_dispersion_index" / "SEA_urban_park_metrics.csv"
ignore_city = ["pontianak", "sarangani"]

# =========================
# Utility Functions
# =========================
def normalize_city(name):
    return name.lower().replace(" ", "").replace("_", "")

def get_safe_centroid(gdf):
    """Calculate the center of the bounding box for CRS determination"""
    minx, miny, maxx, maxy = gdf.total_bounds
    return (minx + maxx) / 2, (miny + maxy) / 2

def get_utm_crs(lon, lat):
    """Determine the appropriate UTM CRS based on longitude and latitude"""
    zone = int((lon + 180) / 6) + 1
    return CRS.from_epsg(32600 + zone) if lat >= 0 else CRS.from_epsg(32700 + zone)

def fix_geometry(geom):
    """Fix invalid geometries using zero-buffer"""
    if geom is None or geom.is_empty:
        return None
    if not geom.is_valid:
        geom = geom.buffer(0)
    return geom if geom.is_valid and not geom.is_empty else None

def lines_to_polygons(gdf):
    """Convert LineStrings/MultiLineStrings to Polygons where possible"""
    polys = []
    for geom in gdf.geometry:
        geom = fix_geometry(geom)
        if geom is None:
            continue

        if geom.geom_type == "Polygon":
            polys.append(geom)
        elif geom.geom_type == "MultiPolygon":
            polys.extend(list(geom.geoms))
        elif geom.geom_type in ["LineString", "MultiLineString"]:
            try:
                poly = Polygon(geom)
                poly = fix_geometry(poly)
                if poly is not None:
                    polys.append(poly)
            except Exception:
                continue

    return gpd.GeoDataFrame(geometry=polys, crs=gdf.crs)

def clip_parks_to_city(park_gdf, city_gdf):
    """Clip park patches to the city administrative boundary"""
    city_union = fix_geometry(city_gdf.unary_union)
    clipped = []

    for geom in park_gdf.geometry:
        geom = fix_geometry(geom)
        if geom is None:
            continue

        if not geom.intersects(city_union):
            continue

        inter = fix_geometry(geom.intersection(city_union))
        if inter is None:
            continue

        if inter.geom_type == "Polygon":
            clipped.append(inter)
        elif inter.geom_type == "MultiPolygon":
            clipped.extend(list(inter.geoms))

    return gpd.GeoDataFrame(geometry=clipped, crs=park_gdf.crs)

# =========================
# Metric Calculations
# =========================
def calc_landscape_metrics(park_gdf, city_area):
    """
    Calculate Landscape Metrics: 
    Patch Density (PD), Largest Patch Index (LPI), and Dispersion (DISP)
    """
    if park_gdf.empty or city_area <= 0:
        return np.nan, np.nan, np.nan

    park_gdf["area"] = park_gdf.geometry.area
    areas = park_gdf["area"].values

    patch_num = len(areas)
    total_area = areas.sum()

    # PD (patches per km2), LPI (%), DISP (Index 0-1)
    PD = patch_num / city_area * 1e6
    LPI = areas.max() / city_area * 100
    DISP = 1 - np.sum((areas / total_area) ** 2)

    return PD, LPI, DISP

def calc_spatial_evenness(park_gdf):
    """
    Calculate Spatial Evenness based on the Coefficient of Variation (CV) 
    of Nearest Neighbor Distances.
    """
    if park_gdf.empty or len(park_gdf) < 2:
        return np.nan

    centroids = park_gdf.geometry.centroid
    coords = np.array([(p.x, p.y) for p in centroids])

    dist_mat = distance_matrix(coords, coords)
    np.fill_diagonal(dist_mat, np.inf)

    nn_dist = dist_mat.min(axis=1)

    mean_d = nn_dist.mean()
    std_d = nn_dist.std()

    if mean_d == 0:
        return np.nan

    SE = std_d / mean_d
    return SE

# =========================
# 1. Get and Sort File Lists
# =========================
park_files = sorted([
    f for f in os.listdir(PARK_DIR)
    if f.endswith(".shp") and normalize_city(os.path.splitext(f)[0]) not in ignore_city
])

city_files = sorted([
    f for f in os.listdir(CITY_DIR)
    if f.endswith(".shp") and normalize_city(os.path.splitext(f)[0]) not in ignore_city
])

assert len(park_files) == len(city_files), "❌ Mismatch between park and city shapefile counts"

print(f"✔ Matched {len(park_files)} cities by sorted filenames")

# =========================
# 2. Main Loop
# =========================
results = []

for park_file, city_file in zip(park_files, city_files):

    city_name = os.path.splitext(park_file)[0]
    print(f"Processing {city_name} ...")

    park_gdf = gpd.read_file(os.path.join(PARK_DIR, park_file))
    city_gdf = gpd.read_file(os.path.join(CITY_DIR, city_file))

    # Remove null geometries
    park_gdf = park_gdf[park_gdf.geometry.notnull()]
    city_gdf = city_gdf[city_gdf.geometry.notnull()]

    # Project to local UTM for accurate area/distance calculation
    cx, cy = get_safe_centroid(city_gdf)
    utm = get_utm_crs(cx, cy)

    park_gdf = park_gdf.to_crs(utm)
    city_gdf = city_gdf.to_crs(utm)

    # Convert lines to polygons if necessary
    park_poly = lines_to_polygons(park_gdf)

    # Clip park patches to city boundary
    park_poly = clip_parks_to_city(park_poly, city_gdf)

    # Get total city area
    city_area = fix_geometry(city_gdf.unary_union).area

    # Calculate metrics
    PD, LPI, DISP = calc_landscape_metrics(park_poly, city_area)
    SE = calc_spatial_evenness(park_poly)

    results.append({
        "city": city_name,
        "patch_density": PD,
        "largest_patch_index": LPI,
        "Patch Dispersion Index": DISP,
    })

# =========================
# Output Results
# =========================
df = pd.DataFrame(results)
df.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")
print("✅ All done! Results saved to CSV.")