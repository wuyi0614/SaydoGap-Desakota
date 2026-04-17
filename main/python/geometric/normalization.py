import pandas as pd
from pathlib import Path

PARENT_DIR = Path("data") / "replication_geometric"
files = {
    PARENT_DIR / "processed" / "blue_exposure_index" / "blue_exposure_index.csv": ["blue_exposure_index"],
    PARENT_DIR / "processed" / "coastal_accessibility_index" / "coastal_proximity.csv": ["coastal_accessibility_index"],
    PARENT_DIR / "processed" / "cropland_ratio" / "cropland_ratio.csv": ["cropland_ratio"],
    PARENT_DIR / "processed" / "green_exposure_index" / "green_exposure_index.csv": ["green_exposure_index"],
    PARENT_DIR / "processed" / "GDP" / "city_gdp_per_capita.xlsx": ["GDP_sum(PPP)", "GDP_per"],
    PARENT_DIR / "processed" / "park_accessibility_index" / "park_accessibility_results.csv": ["Park Accessibility_within_300m", "Park Accessibility_within_500m"],
    PARENT_DIR / "processed" / "patch_density_largest_patch_index_patch_dispersion_index" / "SEA_urban_park_metrics.csv": ["patch_density", "largest_patch_index", "Patch Dispersion Index"],
    PARENT_DIR / "processed" / "per_capita_park _and_park_proportion" / "urban_park_indicators.csv": ["Park Proportion", "Per Capita Park"]
}

def normalize_by_columns(file, columns):
    """Normalize the columns of the file by the columns to normalize."""
    from sklearn.preprocessing import MinMaxScaler

    # Initialize the scaler
    scaler = MinMaxScaler()
    file = Path(file)
    if file.name.endswith('.xlsx') or file.name.endswith('.xls'):
        df = pd.read_excel(file, sheet_name=0)
    else:
        df = pd.read_csv(file)

    print(f"✅ File loaded successfully: {file}")
    print(f"   Shape: {df.shape[0]} rows × {df.shape[1]} columns")

    df_norm = df.copy()
    # Apply normalization only to selected columns (ignores NaN automatically)
    df_norm[columns] = scaler.fit_transform(df[columns])
    print("✅ Min-Max normalization completed.")

    # rename the file to add "_normalized"  
    outfile = file.parent / f"{file.stem}_normalized{file.suffix}"
    if file.name.endswith('.xlsx') or file.name.endswith('.xls'):
        df_norm.to_excel(outfile, index=False)
        print(f"✅ Normalized data saved to new Excel file: {outfile}")
    else:
        df_norm.to_csv(outfile, index=False)
        print(f"✅ Normalized data saved to: {outfile}")


if __name__ == "__main__":
    for file, cols_to_normalize in files.items():
        normalize_by_columns(file, cols_to_normalize)
