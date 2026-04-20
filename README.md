# SAYDOGAP-DESAKOTA

## Replication Code for "Productive urban landscapes override psychological attitudes in driving sustainable consumption"

This repository contains the data and Python & R codes to reproduce all figures, tables, and supplementary materials in the paper.

## Repository Structure

```
SAYDOGAP-DESAKOTA/
├── main/                                                                  # Root script folder
│   ├── python/                                                            # Python codes
│      ├── survey/
│         ├── __init__.py                                                  # Supportive file for intra-module calling
│         ├── config.py                                                    # Configurations and parameters for survey processing
│         └── preprocessing.py                                             # Preprocessing for survey data, return the user panel
│      ├── product/
│         ├── __init__.py                                                  # Supportive file for intra-module calling
│         ├── config.py                                                    # Configurations and parameters for product processing
│         ├── translation.py                                               # Translation pipeline
│         ├── classification.py                                            # Green product classification pipeline
│         ├── preprocessing.py                                             # Preprocessing for product data, return three panels: buyer, survey, city
│         └── stopwords.txt                                                # Customized stopwords for preprocessing
│      ├── analysis/
│         ├── run.py                                                       # Run integrated panels with geo & gap metrics
│         └── Figure3.py                                                   # Create Figure 3: the waterfall chart in the main text
│      ├── geometric/
│         ├── __init__.py                                                  # Supportive file for intra-module calling
│         ├── blue_exposure_index.py                                       # Codes for the blue exposure index
│         ├── coastal_accessibility_index.py                               # Codes for the coastal access index
│         ├── crop_and_greenspace_desakota_index.py                        # Codes for the main desakota index with cropland + greenspace
│         ├── crop_only_desakota_index.py                                  # Codes for the alternative desakota index with cropland only
│         ├── weight_sensitivity_desakota_index.py                         # Codes for the alternative desakota index with weight sensitivity
│         ├── window_sensitivity_desakota_index.py                         # Codes for the alternative desakota index with window sensitivity
│         ├── get_park_polygons_from_OSM.py                                # Extract park polygon vector data from OpenStreetMap
│         ├── get_urban_boundary.py                                        # Extract and generate urban built-up boundary (map projection from `GURS_SA_.tif`)
│         ├── get_water_body_from_OSM.py                                   # Extract water body vector data from OpenStreetMap
│         ├── get_suburban_green_space_from_OSM.py                         # Extract suburban green space data from OpenStreetMap
│         ├── get_urban_residential_area_from_OSM1.py                      # Extract urban residential land data from OpenStreetMap (version 1)
│         ├── get_urban_residential_area_from_OSM2.py                      # Extract urban residential land data from OpenStreetMap (version 2)
│         ├── green_exposure_index.py                                      # Codes for the green exposure index
│         ├── park_accessibility_index.py                                  # Codes for the park accessibility index
│         ├── patch_index.py                                               # Calculate patch density, largest patch index and patch dispersion index
│         ├── park_proportion_index.py                                     # Calculate per capita park area and park proportion indicators
│         ├── normalization.py                                             # Normalize the indexes
│         └── run.py                                                       # Run the calculation of all geometrics
│   ├── R/                                                                 # R codes
│      ├── Figure1.R                                                       # Create the original Figure 1 in the main text
│      ├── Figure2.R                                                       # Create the original Figure 2 in the main text
│      ├── Figure4.R                                                       # Create the original Figure 4 in the main text
│      ├── Figure5.R                                                       # Create the original Figure 5 in the main text
│      ├── SFig1_landscape.R                                               # Create the Supplementary Figure 1
│      ├── STable2_GapRegression.R                                         # Create the Supplementary Table 2
│      ├── SFig3_STable345.Rmd                                             # Create the Supplementary Fgure 3, Table 3-5
│      ├── SFig4_Spatial_vs_NC.R                                           # Create the Supplementary Figure 4
│      ├── STable8_Robustness_ZonalBehavior.R                              # Create the Supplementary Table 8
│      ├── STable67_GAM_Controls.R                                         # Create the Supplementary Table 6-7
│      └── STable18_transformation.R                                       # Create the Supplementary Table 18
│   └── prompter-python/
│     └── prompter-0.1.7-py3-none-any.whl                                  # Customized structured LLM prompters for data retrieval by authors  
├── data/
│   ├── replication-classification/                                        # Replicable input/output data files for green product classification
│      ├── cities/                                                         # Shapfiles for SEA cities in this study with coordinates
│      ├── sample-buyerpanel.csv                                           # Randomly-generated samples (20) before aggregation
│      ├── sample-citypanel-sensitivity-49scenarios.csv                    # Randomly-generated aggregated sample for city-level analysis
│      ├── BPN-LPM-param.jsonl                                             # Detailed parameters for the replication of BPN and LPM variables
│      ├── sample-electronics-classicification.csv                         # Replicable green electronics classficiation from randomly-generated data
│      ├── sample-groceries-classicification.csv                           # Replicable green groceries classficiation from randomly-generated data
│      ├── sample-orderitem.csv                                            # Randomly-generated samples (20) for e-commerce products
│      ├── sample-orderitem-translated.csv                                 # Translated product texts from random samples
│      ├── sample-orderitem-translated.jsonl                               # Translated product texts from random samples directly exported by LLMs
│      ├── sample-survey.csv                                               # Randomly-generated samples (20) for survey respondents
│      ├── sample-sustlabel-electronics-dashscope+qwen-flash.csv           # Identified sustainability labels for green electronics using LLM model 1
│      ├── sample-sustlabel-electronics-dashscope+qwen-max.csv             # Identified sustainability labels for green electronics using LLM model 2
│      ├── sample-sustlabel-groceries-dashscope+qwen-flash.csv             # Identified sustainability labels for green groceries using LLM model 1
│      ├── sample-sustlabel-groceries-dashscope+qwen-max.csv               # Identified sustainability labels for green groceries using LLM model 1
│      ├── sample-usercart.csv                                             # Randomly-generated samples (20) for e-commerce orders
│      └── sample-userorder-mapping.csv                                    # Randomly-generated mappings for e-commerce users and survey respondents
│   ├── replication-figure3/                                               
│      └── fig3-waterfall.xlsx                                             # Metrics and regression coefficients for Figure 3
│   ├── replication-geometric/                                             # Replicable input/output data files for geometric calculation
│      ├── raw/
│         ├── administrative_boundaries _SEA_cities/                       # The same shapfiles from data/cities/
│         ├── coastliine/                                                  # Shapfiles for coastlines
│         ├── global_urban_and_rural_settlement/                           # Shapfiles for global urban and rural settlement
│         ├── land_use/                                                    # TIFF for LUCC
│         ├── park_polygons/                                               # Shapfiles for park polygons
│         ├── population/                                                  # TIFF for population grids
│         ├── residential_polygons/                                        # Shapfiles for residential polygons
│         ├── suburban_green_space/                                        # Shapfiles for suburban green space
│         ├── vegetation/                                                  # Shapfiles for vegetation
│         └── water_polygons/                                              # Shapfiles for water polygons
│      ├── processed/                                                      # Processed data for original & normalized versions
│         ├── blue_exposure_index/
│         ├── coastal_accessibility_index/
│         ├── cropland_ratio/
│         ├── desakota_index/
│         ├── gdp/
│         ├── green_exposure_index/
│         ├── park_accessibility_index/
│         ├── patch_density_largest_patch_index_patch_dispersion_index/
│         ├── per_capita_park_and_park_proportion/
│         ├── sea_city_core/
│         ├── urban_built-up_boundary/
│         └── GeoIndex.xlsx                                                # Integrated data table with columns from the above data files
│   ├── replication-supplementary/                                               
│      ├── SFig2_LPM_Sensitivity.csv                                       # Replicable data table for the Supplementary Figure 2
│      ├── STable3_Desakota_window_sensitivity.csv                         # Replicable data table for the Supplementary Table 3
│      ├── STable4_Desakota_weight_sensitivity.csv                         # Replicable data table for the Supplementary Table 4
│      ├── STable6_ModelComparision.csv                                    # Replicable data table for the Supplementary Table 6
│      ├── STable7_GAM_TurningPoints.csv                                   # Replicable data table for the Supplementary Table 7
│      ├── STable8_Robustness_ZonalBehavior.csv                            # Replicable data table for the Supplementary Table 8
│      └── STable18_Diagnosis_Results.csv                                  # Replicable data table for the Supplementary Table 18
│   ├── GeoIndexV6.xlsx                                                    # The final version of geometric data table for the main analysis
│   ├── IncludingLogData.xlsx                                              # Transformed city-level data for the main analysis
│   ├── MergedPanelV5.csv                                                  # The final version of city-level data table for the main analysis
│   └── CityPanelSensitivity49Scenarios.csv                                # The final version of aggreagated city-level data table without geometrics 
├── figures/                                                               # Figures & tables in the main text
│   ├── raw/                                                               # The original versions of figures in SVG format
│   └── processed/                                                         # Figures in PDF/PNG (final) formats
│      ├── Figure1-GreenIllusion.pdf
│      ├── Figure1_GreenIllusion.png
│      ├── Figure2_CTN_Puzzle.pdf
│      ├── Figure2_CTN_Puzzle.png
│      ├── Figure4_FE.pdf
│      ├── Figure4_FE.png
│      ├── Figure5_Zonal_Master_Electronic.png
│      ├── Figure5_Zonal_Master_Grocery.pdf
│      ├── Figure5_Zonal_Master_Grocery.png
│      ├── SFig1_landscape.png
│      ├── SFig2_LPM_Sensitivity.pdf
│      ├── SFig2_LPM_Sensitivity.png
│      ├── SFig3_Desakota_Sensitivity.png
│      ├── SFig4_Spatial_vs_NC.png
│      ├── SFig5_Distribution_Diagnosis_shifted_log.png
│      ├── STable2_CTNGapRegression.png
│      ├── STable6_ModelComparison.png
│      ├── STable7_GAM_TurningPoints.png
│      ├── STable8_Robustness_ZonalBehavior.png
│      └── STable18_Diagnosis_Results.png
├── .env.template                                                          # The template .env file for the configuration of LLM API requests (delete `.template` before using it)
├── .gitignore                                                             # Git ignore file
├── .python-version                                                        # Required Python version file
├── uv.lock                                                                # Locked dependencies for `uv` env. 
└── README.md                                                              # This file
```

## Data

### Original Input Files

| File | Description | Read by |
|------|-------------|---------|
| `MergedPanel.csv` | Primary survey and behavioral dataset | STable18_tranformation, Figure1, Figure2, SFig2, STable2_GapRegression |
| `GeoIndex.xlsx` | City coordinates (latitude / longitude) for geographic maps | Figure1, SFig2 |
| `CityPanelSensitivity49Scenarios.csv` | Wide-format LPM sensitivity data (150 cities × 1128 columns: 120 base + 1008 sensitivity). Full 7×7 grid of (x0, k) perturbations at 70%–130%. Column suffix: `_x0{pct}%_k{pct}%` (e.g. `_x080%_k130%`). Reshaped to long format (7350 rows) on the fly by SFig2. | SFig2 |

### Intermediate Input

| File | Generated by | Consumed by |
|------|-------------|-------------|
| `IncludingLogData.csv` | `STable18_tranformation.R` — applies shifted-log transforms to skewed variables in `MergedPanel.csv` | Figure4, Figure5, SFig4_Spatial_vs_NC, STable8_Robustness_ZonalBehavior |

## Code Descriptions

### Main Text Figures

| Script | Output | Description |
|--------|--------|-------------|
| `Figure1.R` | Figure 1 | Green Illusion composite: four cascade sub-plots (BPN/LPM x Grocery/Electronic) and geographic distribution map |
| `Figure2.R` | Figure 2 | NC Puzzle: forest plot of Pearson correlations between nature connectedness (NC) and green-related metrics |
| `Figure3.py`| Figure 3 | Waterfall chart for the effects of NC on RG and OB (Figure3a-3t)
| `Figure4.R` | Figure 4 | Panel 4a: forest plot of LPM regression coefficients; Panel 4b: scatter plots with OLS and GAM fits |
| `Figure5.R` | Figure 5 | Zonal classification composite: scatter plot, bar chart, and pie charts by spatial zone |

### Supplementary Figures

| Script | Output | Description |
|--------|--------|-------------|
| `SFig1_landscape.R` | Supp. Figure 1 | Standalone geographic distribution panel for Electronic domain |
| `SFig2_LPM Parameter Sensitivity.R` | Supp. Figure 2 | LPM parameter sensitivity analysis with baseline +/- bands and Moran's I heatmap |
| `SFig3_STable345.Rmd` | Supp. Figure 3 | Desakota index parameter sensitivity analysis with window / weight variations |
| `SFig4_Spatial_vs_NC.R` | Supp. Figure 4 | Spatial greening metrics and nature connectedness (NC) scatter plots |

### Supplementary Tables and Analyses

| Script | Output | Description |
|--------|--------|-------------|
| `STable2_GapRegression.R` | Supp. Table 2 | Regressions of Reporting Gap and Reporting Bias on NC (2 gaps x 2 frameworks x 2 domains) |
| `SFig3_STable345.Rmd` | Supp. Table 3-5 | Desakota index parameter sensitivity analysis with window / weight variations |
| `STable6&7_GAM_Controls.R` | Supp. Tables 6 & 7 | OLS vs Tobit vs GAM model comparison; GAM turning point analysis |
| `STable8_Robustness_ZonalBehavior.R` | Supp. Table 8 | Panel 5b results across 4 specifications (Grocery/Electronic x LPM/BPN) |
| `STable18_tranformation.R` | Supp. Table 18 + intermediate CSV | Variable transformation diagnosis, distribution plots, and log-transformed dataset |

## Dependencies Between Scripts

Most scripts are self-contained. The exceptions are:

| Dependency type | Script | Prerequisite | Reason |
|----------------|--------|-------------|--------|
| **File** | `Figure4.R`, `Figure5.R`, `SFig4_Spatial_vs_NC.R`, `STable8_Robustness_ZonalBehavior.R` | Run `STable18_tranformation.R` first | Reads `output/csv/IncludingLogData20260226.csv` |
| **In-memory** | `SFig1_landscape.R` | Run `Figure1.R` (sections 1–2) first, in the **same R session** | Requires objects: `df`, `df_landscape_electronic`, `theme_nature_sust()`, `coords_matched` |
| **In-memory** | `STable6&7_GAM_Controls.R` | Run `Figure4.R` first, in the **same R session** | Requires objects: `df_z`, `df_plot_b`, `col_green`, `col_desakota` |

## Software Requirements

### R Packages

Install all required packages before running:

```r
install.packages(c(
  # Core
  "dplyr", "tidyr", "tidyverse", "readr", "broom",
  # Visualization
  "ggplot2", "patchwork", "ggrepel", "scales", "cowplot",
  "ggExtra", "ggside", "svglite",
  # Spatial
  "sf", "spdep", "rnaturalearth", "rnaturalearthdata",
  # Modeling
  "mgcv", "boot", "AER", "e1071",
  # Tables and export
  "gt", "knitr", "kableExtra", "webshot2", "extrafont",
  # Excel import
  "readxl"
))
```

### Python env. & dependencies

Install conda environment and make sure Python 3.11 is available for this replication.

Create an individual conda env. for this project via: `conda create -n py311 python=3.11` and activate it before your replication via: `conda activate py311`. 

It is highly recommended to use `uv` to manage the dependencies (make sure you're in `py311` and in the root folder of this project): 

```bash
conda install uv
uv sync
```

Check and edit `pyproject.toml` if you want to view the full list of dependencies and please refer to the usages of `uv` (https://docs.astral.sh/uv/getting-started/first-steps/). 

## How to Reproduce

1. Clone or download this repository.
2. Open R/RStudio and set the working directory to the `SAYDOGAP-DESAKOTA/` folder.
3. Install all required packages and get the environments ready (see above).
4. Run scripts in the following order:

| Step | Script(s) | Notes |
|------|-----------|-------|
| **1** | `STable18_tranformation.R` | **Must run first.** Produces `data/IncludingLogData.csv` needed by 4 downstream scripts. |
| **2** | `Figure1.R`, `Figure2.R`, `Figure4.R`, `Figure5.R`, `SFig2_LPM Parameter Sensitivity.R`, `SFig4_Spatial_vs_NC.R`, `STable2_GapRegression.R`, `STable8_Robustness_ZonalBehavior.R` | Independent of each other; run in any order. |
| **3** | `SFig1_landscape.R` | Run in the **same R session** immediately after `Figure1.R`. |
| **4** | `STable6&7_GAM_Controls.R` | Run in the **same R session** immediately after `Figure4.R`. |
| **5** | `SFig3_STable345.Rmd` | Run in the **same R session** immediately after `Figure4.R`. |
| **6** | `get_*.py` | Run python scripts under `main/python/geometric` starting with `get_`. Notably, `get_urban_boundary.py` must be executed in the first place to produce `SEA_city_core.shp`--the city boundaries. |
| **7** | `*_index.py` | Run python scripts under `main/python/geometric` ending with `index` that generates the original geometric indexes. |
| **8** | `normalization.py` | Run `main/python/geometric/normalization.py` to normalize the indexes generated by `*_index.py`. |
| **9** | `run.py` | Run `main/python/geometric/run.py` to unify normalized indexes from separate files into a single table. |
| **10** | `dataset.py` | Run `main/python/analysis/dataset.py` to create the samples for survey, product, and cart data; also for the aggregated city-level dataset. |
| **11** | `Figure3.py` | Run `main/python/analysis/Figure3.py` to produce the replicable Figure 3 (a waterfall chart). |

6. To replicate the `green product classification` pipeline, edit the `.env.template` to enable API requests via various AI providers, such as ollama (locally deployed), dashscope, openai, deepseek, etc. This pipeline is supported by `prompter v0.1.7` that is a separate project developed by ANGEL, NTU.
7. Notably, due to regulations, we are not allowed to share the original research data, so all the samples are randomly generated following the same structures of the orignal for the replication purpose. The random generation contains ten grocery products and ten electronic products in different languages. 
8. Check the `figures/` subfolders (`raw/` or `processed/`) for all generated figures and tables with / without reframing.

## License

Please cite the associated paper if you use this code or data. (to be updated when DOI or Zenodo links are available)

## Contact Us

Contact us for further enquiries on codes and questions. Let us know if you cannot replicate the results and we will get you in touch as soon as possible.   

Dr. Yi Wu, yiwu@ntu.edu.sg

Dr. Xuan Luo, xuan.luo@ntu.edu.sg
