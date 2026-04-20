# Codes for running the geometric features for the cities
# 

import pandas as pd
from pathlib import Path

# merge the results into a single data panel
folder = Path("data") / "replication_geometric" / "processed"
datafiles = {
    folder / "blue_exposure_index" / "blue_exposure_index_normalized.csv": ["blue_exposure_index"],
    folder / "coastal_accessibility_index" / "coastal_proximity_normalized.csv": ["coastal_accessibility_index"],
    folder / "cropland_ratio" / "cropland_ratio_normalized.csv": ["cropland_ratio"],
    folder / "green_exposure_index" / "green_exposure_index_normalized.csv": ["green_exposure_index"],
    folder / "GDP" / "city_gdp_per_capita_normalized.xlsx": ["GDP_sum(PPP)", "GDP_per"],
    folder / "park_accessibility_index" / "park_accessibility_results_normalized.csv": ["Park Accessibility_within_300m", "Park Accessibility_within_500m"],
    folder / "patch_density_largest_patch_index_patch_dispersion_index" / "SEA_urban_park_metrics_normalized.csv": ["patch_density", "largest_patch_index", "Patch Dispersion Index"],
    folder / "per_capita_park _and_park_proportion" / "urban_park_indicators_normalized.csv": ["Park Proportion", "Per Capita Park"],
    folder / "desakota_index" / "desakota_index_crop_and_greenspace.csv": ["Desakota_Index_CropAndGreen"],
    folder / "desakota_index" / "desakota_index_crop_only.csv": ["Desakota_Index_CropOnly"]
}

mapper = {
    "coastal_accessibility_index": "Coastal Accessibility",
    "green_exposure_index": "Green Exposure Index",
    "blue_exposure_index": "Blue Exposure Index",
    "patch_density": "Patch Density",
    "largest_patch_index": "Largest Patch Index",
    "patch_dispersion_index": "Patch Dispersion Index",
    "green_space_proportion": "Green Space Proportion",
    "per_capita_green_space": "Per Capita Green Space",
    "gdp_sum(PPP)": "GDP_sum(PPP)",
    "gdp_per": "GDP_per",
    "crop_land": "crop_Land",
}

for idx, (file, columns) in enumerate(datafiles.items()):
    if file.name.endswith('.xlsx'):
        panel = pd.read_excel(file)
    else:
        panel = pd.read_csv(file)

    panel = panel[['city', *columns]]
    if idx == 0:
        panel_all = panel.copy()
    else:
        panel_all = pd.merge(panel_all, panel, on='city', how='left')

outfile = Path('data') / "GeoIndex.xlsx"
panel_all.rename(columns=mapper, inplace=True)
panel_all.to_excel(outfile, index=False)
