# =============================================================================
# Supp. Table 2: CTN → Reporting Gap / Reporting Bias Regressions
#
# What it does:
#   Regresses Reporting Gap and Reporting Bias on nature connectedness (CTN),
#   with controls, across all combinations of:
#     Gap type:  Reporting Gap | Reporting Bias
#     Framework: BPN (magnitude) | LPM (probability)
#     Domain:    Grocery | Electronic
#   Total: 2 x 2 x 2 = 8 regressions, displayed in a combined table.
#
# Input:  data/MergedPanelV5.csv
# Output: figures/STable2_CTNGapRegression.png
# =============================================================================
rm(list=ls())

df <- read.csv("data/MergedPanelV5.csv") %>%
  mutate(country=Country,
         isIslam = case_when(
           Main.religion == "Islam" ~ 1,
           TRUE ~ 0),
         isChristian = case_when(
           Main.religion == "Christianity" ~ 1,
           TRUE ~ 0))

library(dplyr)
library(broom)        # For tidy() and glance()
library(knitr)        # For kable()
library(kableExtra)   # For add_header_above, kable_styling

# ==============================================================================
# 1. DATA PRE-PROCESSING: CALCULATE ALL GAPS
# ==============================================================================

df_gaps <- df %>%
  mutate(
    # --- GROCERY DOMAIN ---
    ReportingGap_Grocery_BPN  = stdGreenGroceryLikert_BPN - reportMonthlyGreenGrocery_BPN,
    ReportingBias_Grocery_BPN = reportMonthlyGreenGrocery_BPN - greenSpendingShareGrocery_BPN,
    ReportingGap_Grocery_LPM  = stdGreenGroceryLikert_LPM - reportMonthlyGreenGrocery_LPM,
    ReportingBias_Grocery_LPM = reportMonthlyGreenGrocery_LPM - greenSpendingShareGrocery_LPM,

    # --- ELECTRONIC DOMAIN ---
    ReportingGap_Electronic_BPN  = stdGreenElectronicLikert_BPN - reportMonthlyGreenElectronic_BPN,
    ReportingBias_Electronic_BPN = reportMonthlyGreenElectronic_BPN - greenSpendingShareElectronic_BPN,
    ReportingGap_Electronic_LPM  = stdGreenElectronicLikert_LPM - reportMonthlyGreenElectronic_LPM,
    ReportingBias_Electronic_LPM = reportMonthlyGreenElectronic_LPM - greenSpendingShareElectronic_LPM
  )


# ==============================================================================
# 2. CONFIGURATION
# ==============================================================================

predictor_var <- "genGreenConnectness"
control_vars  <- c("GDP_per", "onlineShoppingExperience", "isHighEdu","socialMediaHrs","Main.religion","country")
formula_rhs   <- paste(c(predictor_var, control_vars), collapse = " + ")

# Clean labels for display 
var_labels <- c(
  "(Intercept)"              = "Intercept",
  "genGreenConnectness"      = "Nature Connectedness (NC)",
  "GDP_per"                  = "GDP per capita",
  "onlineShoppingExperience" = "Online Shopping Exp.",
  "isHighEdu"                = "High Education",
  "socialMediaHrs"           = "Social Media Hrs",
  "Main.religion"            = "Main Religion",
  "Desakota_Index_CropOnly_log" = "Desakota",
  "country"                   = "Country"
)

# ==============================================================================
# 3. RUN ALL 8 REGRESSIONS
# ==============================================================================

gaps    <- c("ReportingGap", "ReportingBias")
domains <- c("Grocery", "Electronic")
metrics <- c("BPN", "LPM")

models <- list()

for (gap in gaps) {
  for (metric in metrics) {
    for (domain in domains) {
      y_var      <- paste(gap, domain, metric, sep = "_")
      f          <- as.formula(paste(y_var, "~", formula_rhs))
      model_name <- paste(gap, metric, domain, sep = "_")
      models[[model_name]] <- lm(f, data = df_gaps)
    }
  }
}

cat("Models created:", length(models), "\n")

# ==============================================================================
# 4. EXTRACT RESULTS & BUILD TABLE
# ==============================================================================

# --- 4a. Column order ---
model_order <- c(
  "ReportingGap_BPN_Grocery",  "ReportingGap_BPN_Electronic",
  "ReportingGap_LPM_Grocery",  "ReportingGap_LPM_Electronic",
  "ReportingBias_BPN_Grocery", "ReportingBias_BPN_Electronic",
  "ReportingBias_LPM_Grocery", "ReportingBias_LPM_Electronic"
)

# --- 4b. Helper: significance stars ---
add_stars <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
}

# --- 4c. Helper: extract tidy coefficients ---
extract_coefs <- function(model) {
  ti <- tidy(model, conf.int = TRUE)
  data.frame(
    term = ti$term,
    est  = sprintf("%.3f%s", ti$estimate, add_stars(ti$p.value)),
    ci   = sprintf("[%.3f, %.3f]", ti$conf.low, ti$conf.high),
    stringsAsFactors = FALSE
  )
}

all_coefs <- lapply(model_order, function(mn) extract_coefs(models[[mn]]))

# --- 4d. Build coefficient rows (estimate + CI per variable) ---
terms <- all_coefs[[1]]$term

rows_list <- list()
for (v in terms) {
  # Row 1: estimate with stars
  est_row <- data.frame(
    Variable = ifelse(v %in% names(var_labels), var_labels[v], v),
    stringsAsFactors = FALSE
  )
  for (i in seq_along(model_order)) {
    est_row[[paste0("M", i)]] <- all_coefs[[i]]$est[all_coefs[[i]]$term == v]
  }
  rows_list[[length(rows_list) + 1]] <- est_row

  # Row 2: confidence interval
  ci_row <- data.frame(Variable = "", stringsAsFactors = FALSE)
  for (i in seq_along(model_order)) {
    ci_row[[paste0("M", i)]] <- all_coefs[[i]]$ci[all_coefs[[i]]$term == v]
  }
  rows_list[[length(rows_list) + 1]] <- ci_row
}
coef_df <- bind_rows(rows_list)

# --- 4e. Extract goodness-of-fit ---
extract_gof <- function(model) {
  gl <- glance(model)
  data.frame(
    N      = sprintf("%d", gl$nobs),
    R2     = sprintf("%.3f", gl$r.squared),
    Adj_R2 = sprintf("%.3f", gl$adj.r.squared),
    F_stat = sprintf("%.2f", gl$statistic),
    p_F    = sprintf("%.4f", gl$p.value),
    stringsAsFactors = FALSE
  )
}

gof_labels <- c("N", "R\u00B2", "Adj. R\u00B2", "F-statistic", "p-value (F)")

gof_rows <- list()
for (g in seq_along(gof_labels)) {
  row <- data.frame(Variable = gof_labels[g], stringsAsFactors = FALSE)
  for (i in seq_along(model_order)) {
    gof_i <- extract_gof(models[[model_order[i]]])
    row[[paste0("M", i)]] <- gof_i[1, g]
  }
  gof_rows[[g]] <- row
}
gof_df <- bind_rows(gof_rows)

# --- 4f. Combine into one data frame ---
full_df <- bind_rows(coef_df, gof_df)
colnames(full_df) <- c(" ", rep(c("Grocery", "Electronic"), 4))

# ==============================================================================
# 5. FORMAT WITH kableExtra (3-LAYER HEADERS)
# ==============================================================================

tab <- kable(full_df, format = "html", align = c("l", rep("c", 8)),
             escape = FALSE, row.names = FALSE) %>%

  # Layer 2: Framework headers (each spans 2 domain columns)
  add_header_above(c(
    " "                           = 1,
    "BPN Framework (Magnitude)"   = 2,
    "LPM Framework (Probability)" = 2,
    "BPN Framework (Magnitude)"   = 2,
    "LPM Framework (Probability)" = 2
  )) %>%

  # Layer 1: Gap headers (each spans 4 columns)
  add_header_above(c(
    " "                              = 1,
    "Reporting Gap"                  = 4,
    "Reporting Bias (Green Illusion)" = 4
  )) %>%

  kable_styling(
    bootstrap_options = c("hover", "condensed"),
    font_size = 11,
    full_width = FALSE
  ) %>%

  # Line between header and first coefficient row
  row_spec(0, extra_css = "border-bottom: 2px solid black;") %>%

  # Line between coefficients and GOF stats
  row_spec(nrow(coef_df), extra_css = "border-bottom: 2px solid black;") %>%

  # Thick BOTTOM border on the last data row
  row_spec(nrow(full_df), extra_css = "border-bottom: 3px solid black;") %>%

  # Vertical separator: thick left border on column 6 (first ReportingBias column)
  column_spec(6, border_left = "2px solid black") %>%

  # Add padding to all data columns for breathing room
  column_spec(2:9, width = "6em", extra_css = "padding-left: 8px; padding-right: 8px;") %>%

  # Variable name column slightly wider
  column_spec(1, width = "10em")

# Inject a full-width top border on the <table> element itself
tab <- gsub(
  '<table',
  '<table style="border-top: 3px solid black; border-collapse: collapse;"',
  tab
)

# Display
tab

# ==============================================================================
# 6. SAVE AS PNG (from the kableExtra HTML table)
# ==============================================================================

library(webshot2)

save_regression_png <- function(tab_kable, filename = "CombinedRegressionTable.png") {
  # Save as temporary HTML
  tmp_html <- tempfile(fileext = ".html")
  save_kable(tab_kable, file = tmp_html)
  
  # Use webshot2 to capture PNG
  webshot2::webshot(
    tmp_html, 
    file = filename,
    vwidth = 1314, 
    vheight = 414,
    zoom = 2,
    delay = 0.5
  )
  
  cat("Saved PNG:", filename, "\n")
  
  # Clean up
  unlink(tmp_html)
}

# Call the function
save_regression_png(tab, "figures/STable2_CTNGapRegression.png")
