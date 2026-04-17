import rasterio
import numpy as np
import geopandas as gpd
from rasterio.features import shapes, geometry_mask
from shapely.geometry import shape
from scipy.ndimage import binary_closing
from skimage.measure import label
from shapely.ops import unary_union
from pathlib import Path

# ======================
# Input / Output
# ======================
PARENT_DIR = Path("data") / "replication_geometric"
gurs_tif = PARENT_DIR / "raw" / "global_urban_and_rural_settlement" / "GURS_SA_.tif"
city_shp = PARENT_DIR / "raw" / "administrative_boundaries _SEA_cities" / "sea-city-with-coordinates.shp"
out_shp = PARENT_DIR / "processed" / "SEA_city_core.shp"

# ======================
# Read City Administrative Regions
# ======================
cities = gpd.read_file(city_shp)
cities = cities[~cities.geometry.isna()].copy()
cities["geometry"] = cities.geometry.buffer(0)

# ======================
# Read GURS
# ======================
with rasterio.open(gurs_tif) as src:
    gurs = src.read(1)
    transform = src.transform
    crs = src.crs
    nodata = src.nodata
    height, width = src.height, src.width

if cities.crs != crs:
    cities = cities.to_crs(crs)

# ======================
# Pre-generate Masks
# ======================
urban_mask = (gurs == 1).astype(np.uint8)
rural_mask = (gurs == 2).astype(np.uint8)

# Morphological parameters
pixel_size = abs(transform.a)
gap_distance = 500
radius = max(1, int(gap_distance / pixel_size))
structure = np.ones((radius, radius), dtype=np.uint8)

# Binary closing (performed separately to maintain logic)
urban_closed = binary_closing(urban_mask, structure=structure)
rural_closed = binary_closing(rural_mask, structure=structure)

# Global connected components
urban_labels = label(urban_closed, connectivity=2)
rural_labels = label(rural_closed, connectivity=2)

# ======================
# Process by City
# ======================
result_geoms = []
result_attrs = []

for idx, city in cities.iterrows():

    geom = city.geometry
    if geom is None or geom.is_empty:
        continue

    try:
        city_mask = geometry_mask(
            [geom],
            out_shape=(height, width),
            transform=transform,
            invert=True
        )
    except ValueError:
        continue

    # ---------- Case 1: Urban clusters exist (value=1) ----------
    city_urban_labels = urban_labels * city_mask
    u_ids, u_counts = np.unique(
        city_urban_labels[city_urban_labels > 0],
        return_counts=True
    )

    if len(u_ids) > 0:
        main_label = u_ids[np.argmax(u_counts)]
        core_mask = (city_urban_labels == main_label).astype(np.uint8)

    # ---------- Case 2: No value 1, only value 2 exists ----------
    else:
        city_rural_labels = rural_labels * city_mask
        r_ids, r_counts = np.unique(
            city_rural_labels[city_rural_labels > 0],
            return_counts=True
        )

        if len(r_ids) == 0:
            continue

        # Select the top 4 largest rural settlement clusters
        top_k = min(4, len(r_ids))
        top_labels = r_ids[np.argsort(r_counts)[-top_k:]]

        core_mask = np.isin(city_rural_labels, top_labels).astype(np.uint8)

    # ---------- Raster to Vector ----------
    geoms = [
        shape(geom)
        for geom, value in shapes(
            core_mask,
            mask=core_mask.astype(bool),
            transform=transform
        )
        if value == 1
    ]

    if not geoms:
        continue

    poly = unary_union(geoms)
    poly = poly.buffer(0)
    poly = poly.simplify(100)

    result_geoms.append(poly)
    result_attrs.append(city.drop("geometry").to_dict())

# ======================
# Output
# ======================
crs = "EPSG:4326"
out_gdf = gpd.GeoDataFrame(
    result_attrs,
    geometry=result_geoms,
    crs=crs
)

out_gdf.to_file(out_shp)
print(f"Saved {len(out_gdf)} city cores to {out_shp}")