################################################################################
# Supp. Table 8: Robustness — Zonal Behavior Across Specifications
#
# What it does:
#   Replicates the Figure 5 Panel 5b zonal analysis across all four
#   framework × domain combinations to check robustness:
#     (1) Grocery × LPM (main), (2) Grocery × BPN,
#     (3) Electronic × LPM,     (4) Electronic × BPN
#
# Input:  data/IncludingLogData.csv
# Output: data/supplementary/STable8_Robustness_ZonalBehavior.csv
#         figures/STable8_Robustness_ZonalBehavior.png
#
# Dependency: Run STable18_tranformation.R first (generates input CSV).
################################################################################
rm(list = ls())
library(dplyr)
library(tidyr)
library(ggplot2)
library(gt)         # install.packages("gt") if needed

# ══════════════════════════════════════════════════════════════════════════════
# Settings
# ══════════════════════════════════════════════════════════════════════════════

THRESH_DESAKOTA <- 0
THRESH_GREEN    <- 0

spatial_vars <- c("Green.Exposure.Index", "Desakota_Index_CropOnly_log")
meta_vars    <- c("city", "country", "isCapitalCity")

# All four specifications
specs <- list(
  list(label = "Grocery × LPM",      domain = "Grocery",    framework = "LPM", main = TRUE),
  list(label = "Grocery × BPN",      domain = "Grocery",    framework = "BPN", main = FALSE),
  list(label = "Electronic × LPM",   domain = "Electronic", framework = "LPM", main = FALSE),
  list(label = "Electronic × BPN",   domain = "Electronic", framework = "BPN", main = FALSE)
)

zone_levels <- c("Aesthetic Green cities", "Grey Infrastructure cities", "Integrated Desakota cities")
zone_short  <- c("Aesthetic Green", "Grey Infrastructure", "Integrated Desakota")

metric_levels <- c("Reported Gap", "Reporting Bias", "Observed Market Behavior")

# ══════════════════════════════════════════════════════════════════════════════
# Load & clean
# ══════════════════════════════════════════════════════════════════════════════

df_raw <- read.csv("data/IncludingLogData.csv")

df_raw <- df_raw %>%
  filter(!grepl("&", city),
         !grepl("(?i)^other$", city, perl = TRUE),
         !is.na(city), city != "")

# Compute all gap columns (both frameworks, both domains)
df_raw <- df_raw %>%
  mutate(
    Gap1_Grocery_LPM       = stdGreenGroceryLikert_LPM    - reportMonthlyGreenGrocery_LPM,
    Gap2_Grocery_LPM       = reportMonthlyGreenGrocery_LPM - greenSpendingShareGrocery_LPM,
    Gap1_Electronic_LPM    = stdGreenElectronicLikert_LPM  - reportMonthlyGreenElectronic_LPM,
    Gap2_Electronic_LPM    = reportMonthlyGreenElectronic_LPM - greenSpendingShareElectronic_LPM,
    Gap1_Grocery_BPN       = stdGreenGroceryLikert_BPN    - reportMonthlyGreenGrocery_BPN,
    Gap2_Grocery_BPN       = reportMonthlyGreenGrocery_BPN - greenSpendingShareGrocery_BPN,
    Gap1_Electronic_BPN    = stdGreenElectronicLikert_BPN  - reportMonthlyGreenElectronic_BPN,
    Gap2_Electronic_BPN    = reportMonthlyGreenElectronic_BPN - greenSpendingShareElectronic_BPN
  )

# Spatial sample (same for all specs — panels 5a & 5c)
df_spatial <- df_raw %>%
  dplyr::select(all_of(c(meta_vars, spatial_vars))) %>%
  drop_na()

classify_zones <- function(data, cols_to_z) {
  data[cols_to_z] <- lapply(data[cols_to_z], function(x) as.numeric(scale(x)))
  data %>%
    mutate(
      Urban_Zone = case_when(
        Desakota_Index_CropOnly_log > THRESH_DESAKOTA                                         ~ "Integrated Desakota cities",
        Desakota_Index_CropOnly_log <= THRESH_DESAKOTA & Green.Exposure.Index > THRESH_GREEN  ~ "Aesthetic Green cities",
        Desakota_Index_CropOnly_log <= THRESH_DESAKOTA & Green.Exposure.Index <= THRESH_GREEN ~ "Grey Infrastructure cities"
      ),
      Urban_Zone = factor(Urban_Zone, levels = zone_levels)
    )
}

# ══════════════════════════════════════════════════════════════════════════════
# Run all four specifications and collect zone_summary tables
# ══════════════════════════════════════════════════════════════════════════════

results <- lapply(specs, function(sp) {
  
  fw  <- sp$framework
  dom <- sp$domain
  
  gap1_col  <- paste0("Gap1_", dom, "_", fw)
  gap2_col  <- paste0("Gap2_", dom, "_", fw)
  spend_col <- paste0("greenSpendingShare", dom, "_", fw)
  
  outcome_vars_sp <- c(gap1_col, gap2_col, spend_col)
  
  df_out <- df_raw %>%
    dplyr::select(all_of(c(meta_vars, spatial_vars, outcome_vars_sp))) %>%
    drop_na()
  
  df_zones <- classify_zones(df_out, c(spatial_vars, outcome_vars_sp))
  
  n_cities <- nrow(df_zones)
  
  summary <- df_zones %>%
    group_by(Urban_Zone) %>%
    summarise(
      `Reported Gap`             = mean(.data[[gap1_col]],  na.rm = TRUE),
      `Reporting Bias`           = mean(.data[[gap2_col]],  na.rm = TRUE),
      `Observed Market Behavior` = mean(.data[[spend_col]], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_longer(cols = -Urban_Zone,
                 names_to  = "Metric",
                 values_to = "Mean_Z") %>%
    mutate(
      Specification = sp$label,
      N             = n_cities,
      is_main       = sp$main,
      Metric        = factor(Metric, levels = metric_levels),
      Urban_Zone    = factor(Urban_Zone, levels = zone_levels)
    )
  
  summary
})

df_results <- bind_rows(results)

# ══════════════════════════════════════════════════════════════════════════════
# Save long-format CSV
# ══════════════════════════════════════════════════════════════════════════════

write.csv(df_results,
          "data/supplementary/STable8_Robustness_ZonalBehavior.csv",
          row.names = FALSE)
cat("Long CSV saved.\n")

# ══════════════════════════════════════════════════════════════════════════════
# Build wide table for display
#   Rows:    Metric × Urban_Zone  (3 metrics × 3 zones = 9 rows)
#   Columns: Specification (4 columns of Mean Z-scores)
# ══════════════════════════════════════════════════════════════════════════════

df_wide <- df_results %>%
  mutate(
    Mean_Z_fmt = sprintf("%.3f", Mean_Z),
    # Append N to spec label
    Spec_N = paste0(Specification, "\n(N = ", N, ")")
  ) %>%
  dplyr::select(Metric, Urban_Zone, Spec_N, Mean_Z_fmt) %>%
  pivot_wider(names_from = Spec_N, values_from = Mean_Z_fmt) %>%
  arrange(Metric, Urban_Zone) %>%
  mutate(
    Zone_short = case_when(
      Urban_Zone == "Aesthetic Green cities"     ~ "Aesthetic Green",
      Urban_Zone == "Grey Infrastructure cities" ~ "Grey Infrastructure",
      Urban_Zone == "Integrated Desakota cities" ~ "Integrated Desakota"
    )
  ) %>%
  dplyr::select(Metric, Zone_short, everything(), -Urban_Zone)

# ══════════════════════════════════════════════════════════════════════════════
# Render gt table and save as PNG
# ══════════════════════════════════════════════════════════════════════════════

zone_colors_tbl <- c(
  "Aesthetic Green"     = "#2E8B4A",
  "Grey Infrastructure" = "#8D8D8D",
  "Integrated Desakota" = "#E07B3A"
)

spec_cols <- setdiff(names(df_wide), c("Metric", "Zone_short"))

gt_tbl <- df_wide %>%
  gt(groupname_col = "Metric", rowname_col = "Zone_short") %>%
  
  # Title
  tab_header(
    title    = md("**Robustness Check: Behavioral Profiles by Urban Zone**"),
    subtitle = md("Average Z-scores across domain × framework specifications. Main specification (Grocery × LPM) in **bold**.")
  ) %>%
  
  # Column labels
  cols_label(Zone_short = "Urban Zone") %>%
  
  # Bold the main spec column
  tab_style(
    style     = cell_text(weight = "bold"),
    locations = cells_column_labels(columns = contains("Grocery × LPM"))
  ) %>%
  tab_style(
    style     = cell_text(weight = "bold"),
    locations = cells_body(columns = contains("Grocery × LPM"))
  ) %>%
  
  # Color zone rows by zone type
  tab_style(
    style     = cell_fill(color = "#2E8B4A22"),
    locations = cells_body(rows = Zone_short == "Aesthetic Green")
  ) %>%
  tab_style(
    style     = cell_fill(color = "#8D8D8D22"),
    locations = cells_body(rows = Zone_short == "Grey Infrastructure")
  ) %>%
  tab_style(
    style     = cell_fill(color = "#E07B3A22"),
    locations = cells_body(rows = Zone_short == "Integrated Desakota")
  ) %>%
  
  # Stub (zone name) colored text
  tab_style(
    style     = cell_text(color = "#2E8B4A", weight = "bold"),
    locations = cells_stub(rows = Zone_short == "Aesthetic Green")
  ) %>%
  tab_style(
    style     = cell_text(color = "#8D8D8D", weight = "bold"),
    locations = cells_stub(rows = Zone_short == "Grey Infrastructure")
  ) %>%
  tab_style(
    style     = cell_text(color = "#E07B3A", weight = "bold"),
    locations = cells_stub(rows = Zone_short == "Integrated Desakota")
  ) %>%
  
  # Source note
  tab_source_note(
    md("*Note:* Z-scores computed within each specification's analytic sample. BPN = Behavioural Potential Normalisation; LPM = Logistic Probability Mapping.")
  ) %>%
  
  # General styling
  tab_options(
    table.font.size          = 12,
    heading.title.font.size  = 14,
    heading.subtitle.font.size = 11,
    row_group.font.weight    = "bold",
    row_group.font.size      = 12,
    column_labels.font.weight = "bold",
    table.border.top.color   = "black",
    table.border.bottom.color = "black",
    column_labels.border.bottom.color = "black"
  )

# Save as PNG
gtsave(gt_tbl,
       "figures/STable8_Robustness_ZonalBehavior.png",
       expand = 20)

cat("Table PNG saved.\n")
print(gt_tbl)
