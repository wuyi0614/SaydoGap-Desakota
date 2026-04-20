# ==============================================================================
# Supp. Table 18: Variable Transformation — Diagnosis & Application
#
# What it does:
#   1. Loads merged_V5_final.csv and computes gap variables
#   2. Diagnoses skewness for spatial and gap variables
#   3. Applies shifted-log transform where |skewness| > threshold
#   4. Exports the transformed dataset (used by Figure4, Figure5, SFig4, STable8)
#   5. Exports diagnosis table (CSV + PNG) and distribution plots
#
# Input:  data/MergedPanel.csv
# Output: data/IncludingLogData.csv  (transformed dataset)
#         data/replication_supplementary/STable18_Diagnosis_Results.csv
#         figures/raw/STable18_Diagnosis_Results.png
#         figures/raw/SFig5_Distribution_Diagnosis_shifted_log.png
#
# NOTE: This script MUST run before Figure4, Figure5, SFig4, STable8.
# ==============================================================================


# ==============================================================================
# SECTION 0: SETUP
# ==============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(dplyr)
  library(e1071)
  library(ggplot2)
  library(patchwork)
  library(scales)
  library(extrafont)
  library(gt)
  library(webshot2)
})

# Base paths for file I/O (no setwd)
base_path  <- "data"
pics_path  <- "figures"


# ==============================================================================
# SECTION 1: DATA LOADING & FEATURE ENGINEERING
# ==============================================================================

df <- read.csv(file.path(base_path, "MergedPanelV5.csv")) %>%
  mutate(country = Country) %>%
  mutate(
    # --- GROCERY DOMAIN ---
    RG_Grocery_BPN  = stdGreenGroceryLikert_BPN  - reportMonthlyGreenGrocery_BPN,
    RB_Grocery_BPN  = reportMonthlyGreenGrocery_BPN  - greenSpendingShareGrocery_BPN,
    RG_Grocery_LPM  = stdGreenGroceryLikert_LPM  - reportMonthlyGreenGrocery_LPM,
    RB_Grocery_LPM  = reportMonthlyGreenGrocery_LPM  - greenSpendingShareGrocery_LPM,
    
    # --- ELECTRONIC DOMAIN ---
    RG_Electronic_BPN = stdGreenElectronicLikert_BPN - reportMonthlyGreenElectronic_BPN,
    RB_Electronic_BPN = reportMonthlyGreenElectronic_BPN - greenSpendingShareElectronic_BPN,
    RG_Electronic_LPM = stdGreenElectronicLikert_LPM - reportMonthlyGreenElectronic_LPM,
    RB_Electronic_LPM = reportMonthlyGreenElectronic_LPM - greenSpendingShareElectronic_LPM
  )


# ==============================================================================
# SECTION 2: TRANSFORMATION REGISTRY
# ==============================================================================

transform_registry <- list(
  
  # Shifted log: log(X + min(X > 0) / 2)
  shifted_log = list(
    fn = function(x) {
      x_pos <- x[!is.na(x) & x > 0]
      if (length(x_pos) == 0) return(rep(NA_real_, length(x)))
      shift <- min(x_pos) / 2
      log(x + shift)
    },
    feasible = function(x) {
      x_complete <- x[!is.na(x)]
      x_pos      <- x_complete[x_complete > 0]
      if (length(x_pos) == 0) return(FALSE)
      shift <- min(x_pos) / 2
      all((x_complete + shift) > 0)
    },
    label        = "Log-shifted",
    formula_expr = expression(paste("log(X + ", frac(min(X > 0), 2), ")")),
    suffix       = "_log",
    description  = "Shift by half the smallest positive value, then log"
  )
)


# ==============================================================================
# SECTION 3: CONFIGURATION
# ==============================================================================

# Active transformation (must match a key in transform_registry)
active_transform <- "shifted_log"

# Skewness threshold for flagging variables
skew_threshold <- 1.5

# Variables to diagnose
vars_to_check <- c(
  "Coastal.Accessibility",
  "Green.Space.Accessibility_within_300m",
  "Green.Space.Accessibility_within_500m",
  "Blue.Exposure.Index",
  "Patch.Density",
  "Largest.Patch.Index",
  "Patch.Dispersion.Index",
  "Green.Exposure.Index",
  "Green.Space.Proportion",
  "Per.Capita.Green.Space",
  "crop_Land",
  "Desakota_Index_CropOnly",
  "Desakota_Index_CropAndGreen",
  "RG_Grocery_BPN",
  "RB_Grocery_BPN",
  "RG_Grocery_LPM",
  "RB_Grocery_LPM",
  "RG_Electronic_BPN",
  "RB_Electronic_BPN",
  "RG_Electronic_LPM",
  "RB_Electronic_LPM"
)


# ==============================================================================
# SECTION 4: DIAGNOSIS & TRANSFORMATION
# ==============================================================================

# Retrieve and validate active transformation
trans <- transform_registry[[active_transform]]
if (is.null(trans)) {
  stop("Unknown transform: '", active_transform,
       "'. Available: ", paste(names(transform_registry), collapse = ", "))
}

cat("\n========================================\n")
cat("Active transformation:", active_transform, "\n")
cat("Description:", trans$description, "\n")
cat("========================================\n")

# Check which requested variables exist in the data
vars_exist   <- vars_to_check[vars_to_check %in% names(df)]
vars_missing <- setdiff(vars_to_check, vars_exist)
if (length(vars_missing) > 0) {
  message("Variables not found in df: ", paste(vars_missing, collapse = ", "))
}

# ---- Diagnosis loop ----
diag_results <- data.frame(
  Variable        = vars_exist,
  N               = NA_integer_,
  Skewness_Raw    = NA_real_,
  Skewness_Trans  = NA_real_,
  Feasible        = NA,
  Needs_Transform = NA,
  stringsAsFactors = FALSE
)

for (i in seq_along(vars_exist)) {
  v          <- vars_exist[i]
  x          <- df[[v]]
  x_complete <- x[!is.na(x)]
  feasible   <- trans$feasible(x)
  sk_raw     <- skewness(x_complete, na.rm = TRUE)
  sk_trans   <- if (feasible) skewness(trans$fn(x), na.rm = TRUE) else NA_real_
  
  diag_results[i, "N"]               <- length(x_complete)
  diag_results[i, "Skewness_Raw"]    <- round(sk_raw,   3)
  diag_results[i, "Skewness_Trans"]  <- round(sk_trans, 3)
  diag_results[i, "Feasible"]        <- feasible
  diag_results[i, "Needs_Transform"] <- (abs(sk_raw) > skew_threshold) & feasible
}

cat("\n===== DIAGNOSIS RESULTS =====\n")
print(diag_results, row.names = FALSE)

# Warn about infeasible high-skew variables
infeasible_vars <- vars_exist[
  !diag_results$Feasible & abs(diag_results$Skewness_Raw) > skew_threshold
]
if (length(infeasible_vars) > 0) {
  cat("\n*** WARNING: These variables need transformation but '", active_transform,
      "' is infeasible:\n", sep = "")
  cat(paste("   ", infeasible_vars, collapse = "\n"), "\n")
  cat("    Consider: ",
      paste(setdiff(names(transform_registry), active_transform), collapse = ", "), "\n")
}

# ---- Apply transformation ----
vars_to_transform <- diag_results$Variable[diag_results$Needs_Transform]

cat("\n===== Transforming", length(vars_to_transform), "variables =====\n")
for (v in vars_to_transform) {
  new_name    <- paste0(v, trans$suffix)
  df[[new_name]] <- trans$fn(df[[v]])
  cat("  ", v, "->", new_name, "\n")
}

# ---- Export transformed dataset ----
write.csv(df, file.path(pics_path, "data/supplementary/IncludingLogData.csv"), row.names = FALSE)
cat("\nTransformed dataset saved → ", file.path(pics_path, "data/supplementary/IncludingLogData.csv"), "\n")

# ---- Before vs After comparison ----
if (length(vars_to_transform) > 0) {
  comparison <- data.frame(
    Variable        = vars_to_transform,
    Skewness_Before = diag_results$Skewness_Raw[diag_results$Needs_Transform],
    Skewness_After  = round(sapply(vars_to_transform, function(v) {
      skewness(df[[paste0(v, trans$suffix)]], na.rm = TRUE)
    }), 3)
  )
  comparison$Improvement <- round(
    abs(comparison$Skewness_Before) - abs(comparison$Skewness_After), 3
  )
  cat("\n===== BEFORE vs AFTER =====\n")
  print(comparison, row.names = FALSE)
}


# ==============================================================================
# SECTION 5: EXPORT DIAGNOSIS TABLE (CSV + PNG)
# ==============================================================================

# ---- Helper: clean variable names for display ----
clean_label <- function(x) {
  x <- gsub("_", " ", x)
  x <- gsub("\\.", " ", x)
  trimws(gsub("\\s+", " ", x))
}

# ---- Prepare display table ----
diag_display <- diag_results %>%
  mutate(
    Variable        = clean_label(Variable),
    Skewness_Raw    = sprintf("%.3f", Skewness_Raw),
    Skewness_Trans  = ifelse(is.na(Skewness_Trans), "—", sprintf("%.3f", Skewness_Trans)),
    Feasible        = ifelse(Feasible, "Yes", "No"),
    Needs_Transform = ifelse(Needs_Transform, "Yes", "No")
  )

colnames(diag_display) <- c(
  "Variable", "N", "Skewness (Raw)",
  "Skewness (Transformed)", "Feasible", "Needs Transform"
)

# ---- Export: CSV ----
csv_path <- file.path(pics_path, "data/supplementary/STable18_Diagnosis_Results.csv")
write.csv(diag_results, csv_path, row.names = FALSE)
cat("\nDiagnosis table saved → ", csv_path, "\n")

# ---- Theme helper ----
apply_gt_theme <- function(gt_obj, tbl_width = pct(100)) {
  n_rows    <- nrow(gt_obj[["_data"]])
  even_rows <- seq(2, n_rows, by = 2)
  
  gt_obj %>%
    tab_style(
      style     = cell_text(weight = "bold"),
      locations = cells_row_groups()
    ) %>%
    tab_style(
      style     = cell_fill(color = "#F5F5F5"),
      locations = cells_body(rows = even_rows)
    ) %>%
    tab_style(
      style     = cell_borders(sides = "bottom", color = "#DDDDDD", weight = px(1)),
      locations = cells_body()
    ) %>%
    tab_style(
      style     = cell_borders(sides  = c("top", "bottom"),
                               color  = "#111111",
                               weight = px(2.5)),
      locations = cells_column_labels()
    ) %>%
    tab_style(
      style     = cell_borders(sides  = "bottom",
                               color  = "#111111",
                               weight = px(2.5)),
      locations = cells_title()
    ) %>%
    tab_style(
      style     = cell_borders(sides  = "bottom",
                               color  = "#111111",
                               weight = px(2.5)),
      locations = cells_body(rows = n_rows)
    ) %>%
    tab_style(
      style     = cell_text(align = "center"),
      locations = cells_column_labels()
    ) %>%
    tab_style(
      style     = cell_text(size = px(11)),
      locations = list(cells_body(), cells_column_labels())
    ) %>%
    tab_style(
      style     = cell_text(size = px(9), color = "#555555"),
      locations = cells_footnotes()
    ) %>%
    tab_style(
      style     = cell_text(size = px(9), color = "#777777"),
      locations = cells_source_notes()
    ) %>%
    tab_options(
      table.font.names                  = "Arial",
      table.border.top.style            = "solid",
      table.border.bottom.style         = "hidden",
      column_labels.border.top.width    = px(0),
      column_labels.border.bottom.width = px(0),
      row_group.border.top.style        = "hidden",
      row_group.border.bottom.style     = "hidden",
      heading.title.font.size           = px(13),
      heading.subtitle.font.size        = px(11),
      heading.align                     = "left",
      table.width                       = tbl_width
    )
}

# ---- Row highlight colours (carried over from original logic) ----
n_rows   <- nrow(diag_display)
row_fill <- rep(NA_character_, n_rows)
row_fill[diag_results$Needs_Transform == TRUE]              <- "#FFF3CD"  # amber
row_fill[diag_results$Feasible == FALSE &
           abs(diag_results$Skewness_Raw) > skew_threshold] <- "#FADADD"  # red

# ---- Build gt table ----
gt_tbl <- diag_display %>%
  gt() %>%
  cols_align(align = "left",   columns = 1) %>%
  cols_align(align = "center", columns = -1) %>%
  apply_gt_theme()

# Apply per-row highlight colours where needed
for (i in seq_len(n_rows)) {
  if (!is.na(row_fill[i])) {
    gt_tbl <- gt_tbl %>%
      tab_style(
        style     = cell_fill(color = row_fill[i]),
        locations = cells_body(rows = i)
      )
  }
}

# Add legend as source notes
gt_tbl <- gt_tbl %>%
  tab_source_note(source_note = md(
    paste0("Highlight key: ",
           "<span style='background:#FFF3CD;padding:1px 6px;'>amber</span> = needs transformation &nbsp;|&nbsp; ",
           "<span style='background:#FADADD;padding:1px 6px;'>red</span> = high skew but transform infeasible")
  )) 
# %>%
#   tab_source_note(source_note = md(
#     paste0("Skewness threshold: |skewness| > ", skew_threshold,
#            " &nbsp;|&nbsp; Transform applied: ", active_transform)
#   ))

# ---- Export: PNG ----
png_path <- file.path(pics_path, "figures/raw/STable18_Diagnosis_Results.png")
gtsave(gt_tbl, filename = png_path, expand = 10)
cat("Diagnosis table (PNG) saved → ", png_path, "\n")


# ==============================================================================
# SECTION 6: DISTRIBUTION PLOTS (Original vs Transformed)
# ==============================================================================

# ---- Plot theme ----
theme_pub <- function(base_size = 7) {
  theme_minimal(base_size = base_size, base_family = "Helvetica") %+replace%
    theme(
      panel.grid.major   = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.background   = element_rect(fill = "white",  colour = NA),
      plot.background    = element_rect(fill = "white",  colour = NA),
      panel.border       = element_blank(),
      axis.line          = element_line(colour = "black", linewidth = 0.3),
      axis.ticks         = element_line(colour = "black", linewidth = 0.25),
      axis.ticks.length  = unit(1.5, "pt"),
      axis.text          = element_text(size = rel(0.85), colour = "black"),
      axis.title         = element_text(size = rel(1.00), colour = "black",
                                        margin = ggplot2::margin(t = 2, r = 2)),
      plot.title         = element_text(size = rel(1.15), face = "bold",
                                        hjust = 0,
                                        margin = ggplot2::margin(b = 3)),
      plot.subtitle      = element_text(size = rel(0.90), colour = "grey30",
                                        hjust = 0,
                                        margin = ggplot2::margin(b = 4)),
      legend.position      = "top",
      legend.justification = "left",
      legend.title         = element_blank(),
      legend.text          = element_text(size = rel(0.85)),
      legend.key.size      = unit(8,  "pt"),
      legend.key           = element_rect(fill = NA, colour = NA),
      legend.margin        = ggplot2::margin(0, 0, 2, 0),
      legend.spacing.x     = unit(3,  "pt"),
      strip.text           = element_text(size = rel(0.95), face = "bold",
                                          hjust = 0,
                                          margin = ggplot2::margin(b = 3)),
      strip.background     = element_rect(fill = NA, colour = NA),
      plot.margin          = ggplot2::margin(6, 8, 4, 6, "pt")
    )
}

# ---- Palette ----
col_original    <- "#B0B0B0"
col_transformed <- "#C94040"

# ---- Build individual density panels ----
plot_list <- lapply(vars_to_transform, function(v) {
  
  v_trans  <- paste0(v, trans$suffix)
  sk_orig  <- round(skewness(df[[v]],      na.rm = TRUE), 2)
  sk_trans <- round(skewness(df[[v_trans]], na.rm = TRUE), 2)
  
  d <- data.frame(
    value = c(df[[v]], df[[v_trans]]),
    type  = factor(
      rep(c("Original", "Transformed"), each = nrow(df)),
      levels = c("Original", "Transformed")
    )
  ) %>% filter(!is.na(value))
  
  ggplot(d, aes(x = value, fill = type, colour = type)) +
    geom_density(alpha = 0.40, linewidth = 0.4, adjust = 1.2) +
    scale_fill_manual(
      values = c(Original = col_original, Transformed = col_transformed),
      labels = c(
        Original    = paste0("Original (skew = ",   sk_orig,  ")"),
        Transformed = paste0(trans$label, " (skew = ", sk_trans, ")")
      )
    ) +
    scale_colour_manual(
      values = c(Original = col_original, Transformed = col_transformed),
      labels = c(
        Original    = paste0("Original (skew = ",   sk_orig,  ")"),
        Transformed = paste0(trans$label, " (skew = ", sk_trans, ")")
      )
    ) +
    scale_x_continuous(labels = label_number(big.mark = ",")) +
    labs(title = clean_label(v), x = "Value", y = "Density") +
    theme_pub() +
    theme(
      legend.position   = "bottom",
      legend.direction  = "vertical",
      legend.spacing.y  = unit(1, "pt"),
      legend.key.height = unit(6, "pt"),
      legend.margin     = ggplot2::margin(t = 2, b = 0),
      legend.text       = element_text(size = rel(0.75))
    )
})
names(plot_list) <- vars_to_transform

# ---- Assemble and export ----
n_panels <- length(plot_list)

if (n_panels > 0) {
  
  ncols  <- min(4, n_panels)
  nrows  <- ceiling(n_panels / ncols)
  
  combined <- wrap_plots(plot_list, ncol = ncols)
  
  fig_w <- 180
  fig_h <- max(60 * nrows, 100)
  
  plot_fname <- file.path(pics_path, "figures/raw",
                          paste0("SFig5_Distribution_Diagnosis_", active_transform, ".png"))
  
  ggsave(
    filename = plot_fname,
    plot     = combined,
    width    = fig_w,
    height   = fig_h,
    units    = "mm",
    dpi      = 600,
    bg       = "white"
  )
  
  cat("\nDistribution plot saved → ", plot_fname, "\n")
  print(combined)
  
} else {
  cat("\nNo variables required transformation — no distribution plots generated.\n")
}
