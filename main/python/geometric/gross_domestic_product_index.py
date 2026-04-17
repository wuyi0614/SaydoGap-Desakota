import os
import numpy as np
import geopandas as gpd
import rasterio
import rasterio.mask
from shapely.geometry import box
from pyproj import CRS
import pandas as pd
from rasterio.warp import calculate_default_transform, reproject, Resampling
from tempfile import TemporaryDirectory
from pathlib import Path

# =========================
# Path settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
SHP_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
GDP_TIF_PATH = PARENT_DIR / "raw" / "gross_domestic_product" / "GDP_SEA.tif"          # 7-band GDP raster
POP_TIF_DIR = PARENT_DIR / "raw" / "population"
OUT_XLSX = PARENT_DIR / "processed" / "GDP" / "city_gdp_per_capita.xlsx"

# Processing parameters
PROCESS_MODE = "all"                    # "all" or "selected"
SELECT_NAMES = ["Cebu"]                 # City names without file extension
BUFFER_M = 60                           # Buffer distance in meters for GDP extraction
BAND_INDEX = 7                          # Band to use from GDP raster (1-based)

# Target equal-area projection for population
TARGET_CRS = "EPSG:6933"                # World Cylindrical Equal Area
TARGET_RES = 30                         # 30 m (for population resampling)

results = []

# =========================
# Tool function: Get UTM CRS based on centroid
# =========================
def get_utm_crs(lon, lat):
    """Return appropriate UTM CRS (EPSG) based on longitude and latitude."""
    zone = int((lon + 180) / 6) + 1
    return CRS.from_epsg(32600 + zone if lat >= 0 else 32700 + zone)


# =========================
# 1. Process GDP (pixel-by-pixel intersection method)
# =========================
print("Starting GDP processing...")

with rasterio.open(GDP_TIF_PATH) as src:
    raster_crs = src.crs
    nodata = src.nodata

    shp_files = [f for f in os.listdir(SHP_DIR) if f.endswith(".shp")]

    for shp_file in shp_files:
        name = os.path.splitext(shp_file)[0]

        if PROCESS_MODE == "selected" and name not in SELECT_NAMES:
            continue

        print(f"▶ Processing GDP for {name}")

        # Read shapefile
        shp_path = os.path.join(SHP_DIR, shp_file)
        shp_gdf = gpd.read_file(shp_path)

        if shp_gdf.crs is None:
            shp_gdf = shp_gdf.set_crs(epsg=4326)

        geom_wgs = shp_gdf.geometry.unary_union

        # Get UTM CRS and buffered extent
        lon, lat = geom_wgs.centroid.xy[0][0], geom_wgs.centroid.xy[1][0]
        utm_crs = get_utm_crs(lon, lat)

        geom_utm = gpd.GeoSeries([geom_wgs], crs=4326).to_crs(utm_crs).iloc[0]
        minx, miny, maxx, maxy = geom_utm.bounds

        extent_buf = box(minx, miny, maxx, maxy).buffer(BUFFER_M)
        extent_wgs = gpd.GeoSeries([extent_buf], crs=utm_crs).to_crs(4326).iloc[0]

        # Clip GDP raster
        clip_img, clip_transform = rasterio.mask.mask(
            src, [extent_wgs], crop=True, all_touched=True
        )

        band = clip_img[BAND_INDEX - 1]

        # Reproject city geometry to raster CRS
        shp_geom = gpd.GeoSeries([geom_wgs], crs=4326).to_crs(raster_crs).iloc[0]

        # Pixel-by-pixel intersection to calculate total GDP
        rows, cols = band.shape
        total_gdp = 0.0

        for r in range(rows):
            for c in range(cols):
                val = band[r, c]
                if nodata is not None and val == nodata:
                    continue
                if np.isnan(val):
                    continue

                x1, y1 = clip_transform * (c, r)
                x2, y2 = clip_transform * (c + 1, r + 1)

                pixel_poly = box(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))

                if pixel_poly.intersects(shp_geom):
                    total_gdp += float(val)

        print(f"    ✔ GDP sum (Band {BAND_INDEX}) = {total_gdp:.2f}")

        # Store temporary result
        results.append({
            "city": name,
            "GDP_sum(PPP)": total_gdp,
            "GDP_per": None   # Will be calculated later
        })


# =========================
# 2. Process Population and Calculate Per Capita GDP
# =========================
print("\nStarting population processing and per capita GDP calculation...")

for i, item in enumerate(results):
    name = item["city"]
    print(f"▶ Processing population for {name}")

    tif_path = POP_TIF_DIR / f"{name}.tif"

    if not tif_path.exists():
        print(f"    ⚠ Missing population tif for {name}, skipping per capita calculation")
        continue

    gdf = gpd.read_file(SHP_DIR / f"{name}.shp")
    gdf = gdf.to_crs(TARGET_CRS)

    with rasterio.open(tif_path) as src:

        # 1. Reproject population raster to equal-area projection
        transform, width, height = calculate_default_transform(
            src.crs, TARGET_CRS, src.width, src.height, *src.bounds
        )

        meta = src.meta.copy()
        meta.update({
            "crs": TARGET_CRS,
            "transform": transform,
            "width": width,
            "height": height
        })

        with TemporaryDirectory() as tmpdir:
            reproj_tif = tmpdir / "reproj.tif"

            with rasterio.open(reproj_tif, "w", **meta) as dst:
                reproject(
                    source=rasterio.band(src, 1),
                    destination=rasterio.band(dst, 1),
                    src_transform=src.transform,
                    src_crs=src.crs,
                    dst_transform=transform,
                    dst_crs=TARGET_CRS,
                    resampling=Resampling.nearest
                )

            # 2. Resample to 30 m
            with rasterio.open(reproj_tif) as reproj_src:
                scale_x = reproj_src.res[0] / TARGET_RES
                scale_y = reproj_src.res[1] / TARGET_RES

                new_width = int(reproj_src.width * scale_x)
                new_height = int(reproj_src.height * scale_y)

                new_transform = rasterio.transform.from_origin(
                    reproj_src.bounds.left,
                    reproj_src.bounds.top,
                    TARGET_RES,
                    TARGET_RES
                )

                resampled = np.zeros((new_height, new_width), dtype=np.float32)

                reproject(
                    source=rasterio.band(reproj_src, 1),
                    destination=resampled,
                    src_transform=reproj_src.transform,
                    src_crs=TARGET_CRS,
                    dst_transform=new_transform,
                    dst_crs=TARGET_CRS,
                    resampling=Resampling.average
                )

                # 3. Mask and sum population
                with rasterio.io.MemoryFile() as memfile:
                    with memfile.open(
                        driver="GTiff",
                        height=new_height,
                        width=new_width,
                        count=1,
                        dtype="float32",
                        crs=TARGET_CRS,
                        transform=new_transform,
                        nodata=0
                    ) as tmp_ds:
                        tmp_ds.write(resampled, 1)

                        out_img, _ = rasterio.mask.mask(
                            tmp_ds,
                            gdf.geometry,
                            crop=False,
                            all_touched=True,
                            nodata=0
                        )

                        pop_sum = np.nansum(out_img)

    # Adjust population
    adjusted_pop = round(pop_sum / 11.11)

    # Calculate per capita GDP
    per_capita = round(item["GDP_sum(PPP)"] / adjusted_pop, 2) if adjusted_pop > 0 else None

    # Update result
    results[i]["GDP_per"] = per_capita


# =========================
# Save final results to Excel (without population column)
# =========================
df = pd.DataFrame(results)
df = df[["city", "GDP_sum(PPP)", "GDP_per"]]

df.to_excel(OUT_XLSX, index=False)

print("\n🎉 All processing completed!")
print(f"Results saved to: {OUT_XLSX}")