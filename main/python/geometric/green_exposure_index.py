import os
import geopandas as gpd
import rasterio
from rasterio.mask import mask
from rasterio.windows import from_bounds
import numpy as np
import pandas as pd
from pathlib import Path

# =========================
# Path Settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
BUILTUP_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
NDVI_DIR = PARENT_DIR / "raw" / "vegetation"
POP_DIR = PARENT_DIR / "raw" / "population"
OUT_CSV = PARENT_DIR / "processed" / "green_exposure_index" / "green_exposure_index.csv"

# =========================
# Processing Control Switch
# =========================
PROCESS_ALL = True  # True = process all cities, False = process only first N cities
MAX_CITIES = 5  # Only effective when PROCESS_ALL = False

# =========================
# Main Processing
# =========================
results = []

# Get all shapefiles and sort them for consistent order
shp_list = [f for f in os.listdir(BUILTUP_DIR) if f.endswith(".shp")]
shp_list.sort()  # Ensure consistent processing order

print(f"Found {len(shp_list)} cities in total.")

if not PROCESS_ALL:
    shp_list = shp_list[:MAX_CITIES]
    print(f"Processing only the first {MAX_CITIES} cities (test mode).")

for shp_name in shp_list:
    city = os.path.splitext(shp_name)[0]
    print(f"▶ Processing {city} ({shp_list.index(shp_name) + 1}/{len(shp_list)})")

    shp_path = os.path.join(BUILTUP_DIR, shp_name)
    ndvi_path = os.path.join(NDVI_DIR, f"{city}.tif")
    pop_path = os.path.join(POP_DIR, f"{city}.tif")

    if not (os.path.exists(ndvi_path) and os.path.exists(pop_path)):
        print(f"    ⚠ Missing data for {city}, skipping...")
        continue

    # Read built-up area geometry
    gdf = gpd.read_file(shp_path)
    geom = gdf.geometry.union_all()

    # Mask WorldPop data
    with rasterio.open(pop_path) as pop_src:
        pop_img, pop_transform = mask(pop_src, [geom], crop=True)
        pop_data = pop_img[0]

    valid_pop = np.isfinite(pop_data) & (pop_data > 0)
    if valid_pop.sum() == 0:
        print(f"    ⚠ No valid population data for {city}")
        results.append([city, np.nan])
        continue

    with rasterio.open(ndvi_path) as ndvi_src:
        ndvi_nodata = ndvi_src.nodata
        ndvi_transform = ndvi_src.transform

        weighted_sum = 0.0
        pop_sum = 0.0

        # Get indices of valid population pixels
        rows, cols = np.where(valid_pop)

        for r, c in zip(rows, cols):
            pop_value = pop_data[r, c]

            # Calculate spatial bounds of current population pixel
            x_min, y_max = pop_transform * (c, r)
            x_max, y_min = pop_transform * (c + 1, r + 1)

            # Create window for NDVI sampling
            window = from_bounds(
                x_min, y_min, x_max, y_max,
                transform=ndvi_transform
            )

            # Read NDVI block for this population pixel
            ndvi_block = ndvi_src.read(
                1, window=window, boundless=True, fill_value=np.nan
            )

            # Define valid NDVI values
            valid_ndvi = ndvi_block[
                np.isfinite(ndvi_block) &
                (ndvi_block != ndvi_nodata) &
                (ndvi_block >= 0) &
                (ndvi_block <= 10000)
                ]

            if valid_ndvi.size == 0:
                continue

            ndvi_mean = valid_ndvi.mean()

            weighted_sum += ndvi_mean * pop_value
            pop_sum += pop_value

    # Calculate Green Exposure Index (GEI)
    gei = weighted_sum / pop_sum if pop_sum > 0 else np.nan

    results.append([city, gei])
    print(f"    ✔ {city} GEI = {gei:.4f}" if not np.isnan(gei) else f"    ✔ {city} GEI = NaN")

# =========================
# Output results
# =========================
df = pd.DataFrame(results, columns=["city", "Green Exposure Index"])
df.to_csv(OUT_CSV, index=False)

print("\n✅ Green Exposure Index calculation finished.")
print(f"Total cities processed: {len(results)}")
print(f"Results saved to: {OUT_CSV}")