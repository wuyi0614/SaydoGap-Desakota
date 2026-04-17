import geopandas as gpd
import pandas as pd
import rasterio
from rasterio.mask import mask
from shapely.ops import unary_union
import numpy as np
import os
from pathlib import Path

# =========================
# Path Settings
# =========================
PARENT_DIR = Path("data") / "replication_geometric"
BUILTUP_DIR = PARENT_DIR / "processed" / "urban_built-up_boundary"
RES_DIR = PARENT_DIR / "raw" / "residential_polygons"
POP_DIR = PARENT_DIR / "raw" / "population"
COASTLINE = PARENT_DIR / "raw" / "coastline" / "ne_50m_coastline" / "ne_50m_coastline.shp"
OUT_CSV = PARENT_DIR / "processed" / "coastal_accessibility_index" / "coastal_proximity.csv"

# =========================
# Coastline (WGS84)
# =========================
print("Loading coastline...")
coast = gpd.read_file(COASTLINE)
coast_geom = unary_union(coast.geometry)

results = []
# =========================
# 读取三个文件夹的文件列表
# =========================
res_files = [f for f in os.listdir(RES_DIR) if f.endswith(".shp")]
built_files = [f for f in os.listdir(BUILTUP_DIR) if f.endswith(".shp")]
pop_files = [f for f in os.listdir(POP_DIR) if f.endswith(".tif")]

# 创建匹配字典：把 built 和 pop 的文件名空格替换为下划线后作为 key
built_dict = {}
pop_dict = {}

for f in built_files:
    key = os.path.splitext(f)[0].replace(" ", "_")   # 空格替换为下划线
    built_dict[key] = f

for f in pop_files:
    key = os.path.splitext(f)[0].replace(" ", "_")
    pop_dict[key] = f

# 以 RES_DIR 中的文件为基准进行匹配
res_files_sorted = sorted(res_files)   # 可根据需要排序或不排序

print(f"Total residential files: {len(res_files_sorted)}\n")

# =========================
# Main Loop - 按文件名匹配逻辑处理
# =========================
for res_f in res_files_sorted:
    city_key = os.path.splitext(res_f)[0]           # RES 文件名（不带扩展名）
    city_name = city_key.replace("_", " ")          # 可选：用于显示更友好

    print(f"Processing {city_name}  (key: {city_key})")

    # 查找对应的 built 和 pop 文件
    built_f = built_dict.get(city_key)
    pop_f = pop_dict.get(city_key)

    if not built_f:
        print(f"  ⚠ No matching built-up file for key: {city_key}")
        continue
    if not pop_f:
        print(f"  ⚠ No matching WorldPop file for key: {city_key}")

    try:
        # ---------- Read Data ----------
        res = gpd.read_file(Path(RES_DIR) / res_f)
        built = gpd.read_file(Path(BUILTUP_DIR) / built_f)

        # ---------- Clip Residential Areas ----------
        res_clipped = gpd.overlay(res, built, how="intersection")

        if res_clipped.empty:
            print("  ⚠ No residential area after clipping")
            results.append({
                "city": city_key,
                "coastal_accessibility_index": np.nan,
            })
            continue

        # ---------- Distance to Coast ----------
        res_clipped = res_clipped.copy()
        res_clipped["rep_pt"] = res_clipped.geometry.representative_point()
        res_clipped["dist_coast_deg"] = res_clipped["rep_pt"].apply(
            lambda p: p.distance(coast_geom)
        )
        MRDC = res_clipped["dist_coast_deg"].mean()

        # ---------- WorldPop Calculation ----------
        total_pop = np.nan
        PMRDC = np.nan

        with rasterio.open(Path(POP_DIR) / pop_f) as src:
            try:
                pop_arr, _ = mask(
                    src,
                    res_clipped.geometry,
                    crop=True,
                    filled=False
                )

                pop = pop_arr[0]
                valid_pop = pop[~pop.mask]

                if valid_pop.size > 0:
                    total_pop = float(valid_pop.sum())
                    PMRDC = MRDC

            except Exception as pop_err:
                print(f"  ⚠ Population raster error: {pop_err}")

        # ---------- Save Result ----------
        results.append({
            "city": city_key,
            "coastal_accessibility_index": MRDC,
        })

        pop_display = f"{total_pop:,.0f}" if pd.notna(total_pop) else "N/A"
        print(f"  → MRDC: {MRDC:.6f} deg | Pop: {pop_display}")

    except Exception as e:
        print(f"  ❌ Error processing {city_key}: {e}")
        results.append({
            "city": city_key,
            "coastal_accessibility_index": np.nan,
        })

# =========================
# Output
# =========================
df = pd.DataFrame(results)
os.makedirs(os.path.dirname(OUT_CSV), exist_ok=True)
df.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")

print("\n✅ All cities processed.")
print(f"Results saved to: {OUT_CSV}")