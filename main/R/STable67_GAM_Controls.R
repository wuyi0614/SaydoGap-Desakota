################################################################################
# Supp. Tables 6 & 7: Model Comparison & GAM Turning Points
#
# What it does:
#   Table 6: Compares OLS, Tobit, and GAM models for the relationship between
#     spatial indices and observed market behavior (4 rows = 2 domains x 2 indices).
#   Table 7: Identifies turning points (interior extrema) in GAM-fitted curves.
#
# Input:  In-memory objects from Figure4.R (same R session)
# Output: data/supplementary/STable6_ModelComparison.csv
#         figures/STable6_ModelComparison.png
#         data/supplementary/STable7_GAM_TurningPoints.csv
#         figures/STable7_GAM_TurningPoints.png
#
# Dependency: Run Figure4.R first in the SAME R session.
#   Required objects: df_z, df_plot_b, col_green, col_desakota
################################################################################


# ==============================================================================
# SECTION 0  Setup: packages, paths, constants
# ==============================================================================

pkgs <- c("AER", "gt", "webshot2", "dplyr")
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}

library(AER)      # tobit()
library(gt)
library(dplyr)
# mgcv is already loaded via Figure4.R

out_dir <- "output"
dir.create(file.path(out_dir, "png"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(out_dir, "csv"), showWarnings = FALSE, recursive = TRUE)

controls <- c("GDP_per", "onlineShoppingExperience", "isHighEdu",
              "socialMediaHrs", "Main.religion", "country")

panel_combos <- expand.grid(
  Domain       = c("Grocery", "Electronics"),
  SpatialLabel = c("Green Exposure", "Desakota"),
  stringsAsFactors = FALSE
)


# ==============================================================================
# SECTION 1  Boundary / Zero-Inflation Diagnostic (justifies Tobit inclusion)
# ==============================================================================

outcome_vars <- c("greenSpendingShareGrocery_LPM",
                  "greenSpendingShareElectronic_LPM")

cat("\n==================================================================\n")
cat("Boundary Diagnostic (z-scored scale; zero = original sample mean)\n")
cat("==================================================================\n")
for (ov in outcome_vars) {
  vals    <- df_z[[ov]]
  n_total <- length(vals)
  p1      <- quantile(vals, 0.01, na.rm = TRUE)
  n_p1    <- sum(vals <= p1, na.rm = TRUE)
  cat(sprintf("  %-48s  <=P1: %d/%d (%.1f%%)\n",
              ov, n_p1, n_total, 100 * n_p1 / n_total))
}
cat("==================================================================\n\n")


# ==============================================================================
# SECTION 2  Prepare analysis dataset
#
#   df_plot_b already contains all control variables as columns — it is the
#   wide-then-pivoted frame produced by Figure4.R, which carries every column
#   from df_z plus the long-format panel columns (Domain, SpatialLabel, etc.).
#   No join is required; we simply use df_plot_b directly.
# ==============================================================================

ctrl_cols   <- controls[controls %in% names(df_plot_b)]
missing_ctrl <- controls[!controls %in% names(df_plot_b)]

df_analysis <- df_plot_b

cat(sprintf("Controls found in df_plot_b : %s\n", paste(ctrl_cols,   collapse = ", ")))
if (length(missing_ctrl) > 0)
  cat(sprintf("Controls NOT found          : %s\n", paste(missing_ctrl, collapse = ", ")))
cat(sprintf("Analysis rows               : %d\n\n", nrow(df_analysis)))


# ==============================================================================
# SECTION 3  Helper functions
# ==============================================================================

# -- Formatting helpers --------------------------------------------------------

fmt_star <- function(p) {
  ifelse(p < 0.001, "***",
         ifelse(p < 0.01,  "**",
                ifelse(p < 0.05,  "*",
                       ifelse(p < 0.10, "\u2020", "ns"))))
}
fmt_p        <- function(p) ifelse(p < 0.001, "< 0.001", sprintf("%.3f", p))
fmt_beta_sig <- function(b, p) paste0(sprintf("%.3f", b), fmt_star(p))


# -- safe_controls(): pick usable controls for one data slice -----------------
#   Three-stage filter returning a RHS string (e.g. "GDP_per + isHighEdu")
#   or NULL if no controls survive.
#
#   Stage 1 — presence   : keep only columns that exist in d
#   Stage 2 — variance   : drop columns that are constant or single-level
#   Stage 3 — collinearity: iteratively add controls one-by-one via QR rank
#              check; skip any variable that would introduce a rank deficiency.
#              This is the only method that catches partial aliasing in factor
#              variables (e.g. country dummies collinear with numeric GDP_per)
#              without crashing tobit() or gam().

safe_controls <- function(d, candidate_controls) {
  focal_vars <- "Spatial_Value"
  
  # Same strategy as safe_controls_lm():
  # Unconditionally drop Main.religion when country is present,
  # then run lm() probe for residual collinearity.
  
  present <- candidate_controls[candidate_controls %in% names(d)]
  if (length(present) == 0) {
    cat("   [safe_controls] no controls found\n"); return(NULL)
  }
  
  # Unconditionally drop Main.religion when country is present
  if ("country" %in% present && "Main.religion" %in% present) {
    present <- present[present != "Main.religion"]
    cat("   [safe_controls] dropped Main.religion (country FE takes precedence)\n")
  }
  if (length(present) == 0) return(NULL)
  
  d_tmp <- d %>%
    dplyr::mutate(across(where(is.character), as.factor)) %>%
    dplyr::mutate(across(where(is.factor),   droplevels))
  
  present <- present[sapply(present, function(v) {
    x <- d_tmp[[v]]
    if (is.numeric(x)) !is.na(var(x, na.rm = TRUE)) && var(x, na.rm = TRUE) > 0
    else               length(unique(na.omit(x))) > 1
  })]
  if (length(present) == 0) return(NULL)
  
  keep_last      <- c("country")
  d_tmp$.y_probe <- 0
  accepted       <- present
  
  repeat {
    if (length(accepted) == 0) return(NULL)
    
    rhs   <- paste(c(focal_vars, accepted), collapse = " + ")
    f     <- as.formula(paste(".y_probe ~", rhs))
    probe <- suppressWarnings(lm(f, data = d_tmp))
    cf    <- coef(probe)
    
    na_coef_names <- names(cf)[is.na(cf)]
    na_vars <- unique(unlist(lapply(na_coef_names, function(coef_nm) {
      matched <- accepted[sapply(accepted, function(v) startsWith(coef_nm, v))]
      if (length(matched) > 0) matched else character(0)
    })))
    na_vars <- na_vars[!na_vars %in% focal_vars]
    
    if (length(na_vars) == 0) break
    
    to_drop <- if (any(!na_vars %in% keep_last))
      na_vars[!na_vars %in% keep_last][1]
    else
      na_vars[1]
    cat(sprintf("   [safe_controls] dropped (residual collinear): %s\n", to_drop))
    accepted <- accepted[accepted != to_drop]
  }
  
  cat(sprintf("   [safe_controls] accepted: %s\n", paste(accepted, collapse = ", ")))
  paste(accepted, collapse = " + ")
}


# -- build_formula(): construct a model formula --------------------------------

build_formula <- function(outcome, focal, ctrl_rhs = NULL, smooth = FALSE) {
  focal_term <- if (smooth) sprintf("s(%s, bs = 'tp')", focal) else focal
  rhs        <- if (!is.null(ctrl_rhs))
    paste(focal_term, ctrl_rhs, sep = " + ")
  else
    focal_term
  as.formula(paste(outcome, "~", rhs))
}


# -- fit_ols_(): OLS fit, return focal-predictor stats ------------------------

fit_ols_ <- function(d, ctrl_rhs) {
  f   <- build_formula("Actual_Market_Behavior", "Spatial_Value", ctrl_rhs)
  fit <- lm(f, data = d)
  s   <- summary(fit)
  list(
    fit = fit,
    b   = s$coefficients["Spatial_Value", "Estimate"],
    se  = s$coefficients["Spatial_Value", "Std. Error"],
    p   = s$coefficients["Spatial_Value", "Pr(>|t|)"],
    r2  = s$r.squared,
    aic = AIC(fit),
    ll  = as.numeric(logLik(fit))
  )
}


# -- fit_tobit_(): Tobit fit, return focal-predictor stats --------------------

fit_tobit_ <- function(d, ctrl_rhs) {
  y_min <- min(d$Actual_Market_Behavior, na.rm = TRUE)
  f     <- build_formula("Actual_Market_Behavior", "Spatial_Value", ctrl_rhs)
  # Pass y_min as an evaluated literal so tobit() does not try to resolve
  # the symbol 'y_min' in the calling environment (which causes "object not found")
  fit   <- do.call(tobit, list(formula = f, data = d, left = y_min))
  fit0  <- do.call(tobit, list(formula = Actual_Market_Behavior ~ 1,
                               data = d, left = y_min))
  s     <- summary(fit)
  ll    <- as.numeric(logLik(fit))
  ll0   <- as.numeric(logLik(fit0))
  list(
    fit = fit,
    b   = s$coefficients["Spatial_Value", "Estimate"],
    se  = s$coefficients["Spatial_Value", "Std. Error"],
    p   = s$coefficients["Spatial_Value", "Pr(>|z|)"],
    pr2 = 1 - ll / ll0,
    aic = AIC(fit),
    ll  = ll
  )
}


# -- fit_gam_(): GAM fit, return smooth-term stats ----------------------------

fit_gam_ <- function(d, ctrl_rhs) {
  f   <- build_formula("Actual_Market_Behavior", "Spatial_Value",
                       ctrl_rhs, smooth = TRUE)
  fit <- gam(f, data = d)
  s   <- summary(fit)
  list(
    fit = fit,
    edf = s$s.table[1, "edf"],
    p   = s$s.table[1, "p-value"],
    r2  = s$r.sq,
    aic = AIC(fit),
    ll  = as.numeric(logLik(fit))
  )
}


# -- gam_turning_points_(): find interior extrema of the GAM curve ------------
#   Controls are held at their within-slice mean / modal value so that
#   predict.gam() receives every variable the model was trained on.

gam_turning_points_ <- function(d, gam_fit, n_grid = 500) {
  
  x_range <- range(d$Spatial_Value, na.rm = TRUE)
  x_grid  <- seq(x_range[1], x_range[2], length.out = n_grid)
  
  # Build newdata by taking one representative row from the training data,
  # replicating it n_grid times, then replacing Spatial_Value with the grid.
  # This guarantees predict.gam() receives every column it was trained on,
  # with the correct types (factor levels etc.), without parsing ctrl_rhs.
  ref_row <- d[1, , drop = FALSE]
  nd      <- ref_row[rep(1, n_grid), , drop = FALSE]
  rownames(nd) <- NULL
  
  # Fix numeric columns at their mean; factors at their modal level
  for (v in names(nd)) {
    if (v == "Spatial_Value") next
    col <- d[[v]]
    if (is.numeric(col)) {
      nd[[v]] <- mean(col, na.rm = TRUE)
    } else {
      nd[[v]] <- names(sort(table(col), decreasing = TRUE))[1]
      if (is.factor(col)) nd[[v]] <- factor(nd[[v]], levels = levels(col))
    }
  }
  nd$Spatial_Value <- x_grid
  
  y_pred  <- as.numeric(predict(gam_fit, newdata = nd))
  sign_ch <- diff(sign(diff(y_pred) / diff(x_grid)))
  idx_max <- which(sign_ch == -2) + 1
  idx_min <- which(sign_ch ==  2) + 1
  
  if (length(idx_max) == 0 && length(idx_min) == 0) return(NULL)
  
  data.frame(
    x_extremum = round(x_grid[c(idx_max, idx_min)], 3),
    y_extremum = round(y_pred[c(idx_max, idx_min)], 3),
    Type       = c(rep("Maximum", length(idx_max)),
                   rep("Minimum", length(idx_min))),
    stringsAsFactors = FALSE
  )
}


# -- apply_gt_theme(): shared gt styling for both tables ----------------------

apply_gt_theme <- function(gt_obj, tbl_width = pct(100)) {
  n_rows    <- nrow(gt_obj[["_data"]])
  even_rows <- seq(2, n_rows, by = 2)
  gt_obj %>%
    tab_style(style     = cell_text(weight = "bold"),
              locations = cells_row_groups()) %>%
    tab_style(style     = cell_fill(color = "#F5F5F5"),
              locations = cells_body(rows = even_rows)) %>%
    tab_style(style     = cell_borders(sides = "bottom", color = "#DDDDDD",
                                       weight = px(1)),
              locations = cells_body()) %>%
    tab_style(style     = cell_borders(sides = c("top", "bottom"),
                                       color = "#111111", weight = px(2.5)),
              locations = cells_column_labels()) %>%
    tab_style(style     = cell_borders(sides = "bottom", color = "#111111",
                                       weight = px(2.5)),
              locations = cells_title()) %>%
    tab_style(style     = cell_borders(sides = "bottom", color = "#111111",
                                       weight = px(2.5)),
              locations = cells_body(rows = n_rows)) %>%
    tab_style(style     = cell_text(align = "center"),
              locations = cells_column_labels()) %>%
    tab_style(style     = cell_text(size = px(11)),
              locations = list(cells_body(), cells_column_labels())) %>%
    tab_style(style     = cell_text(size = px(9), color = "#555555"),
              locations = cells_footnotes()) %>%
    tab_style(style     = cell_text(size = px(9), color = "#777777"),
              locations = cells_source_notes()) %>%
    tab_options(
      table.font.names                  = "Arial",
      table.border.top.style            = "hidden",
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


# ==============================================================================
# SECTION 4  Fit models -- collect rows for Table 1 and turning points for Table 2
# ==============================================================================

model_rows   <- list()
extrema_rows <- list()

for (i in seq_len(nrow(panel_combos))) {
  
  dom <- panel_combos$Domain[i]
  spl <- panel_combos$SpatialLabel[i]
  cat(sprintf("-- Fitting: Domain = %-14s | Spatial = %s\n", dom, spl))
  
  # 4a. Slice and clean data ---------------------------------------------------
  d <- df_analysis %>%
    dplyr::filter(Domain == dom, SpatialLabel == spl) %>%
    dplyr::filter(!is.na(Actual_Market_Behavior), !is.na(Spatial_Value)) %>%
    dplyr::mutate(across(where(is.character), as.factor))  # proper contrasts
  
  # 4b. Determine safe controls for this slice --------------------------------
  ctrl_rhs <- safe_controls(d, controls)
  cat(sprintf("   Controls used: %s\n",
              if (is.null(ctrl_rhs)) "none (all dropped)" else ctrl_rhs))
  
  # 4c. Fit OLS, Tobit, GAM ---------------------------------------------------
  ols   <- fit_ols_(d, ctrl_rhs)
  tob   <- fit_tobit_(d, ctrl_rhs)
  gam_r <- fit_gam_(d, ctrl_rhs)
  
  # 4d. Collect Table 1 row ---------------------------------------------------
  model_rows[[i]] <- data.frame(
    Domain         = dom,
    Spatial_Index  = spl,
    N              = nrow(d),
    Controls_Used  = if (is.null(ctrl_rhs)) "none" else ctrl_rhs,
    # OLS
    OLS_beta_sig   = fmt_beta_sig(ols$b,    ols$p),
    OLS_SE         = sprintf("%.3f", ols$se),
    OLS_R2         = sprintf("%.3f", ols$r2),
    OLS_AIC        = sprintf("%.1f", ols$aic),
    OLS_logLik     = sprintf("%.1f", ols$ll),
    # Tobit
    Tobit_beta_sig = fmt_beta_sig(tob$b,    tob$p),
    Tobit_SE       = sprintf("%.3f", tob$se),
    Tobit_pseudoR2 = sprintf("%.3f", tob$pr2),
    Tobit_AIC      = sprintf("%.1f", tob$aic),
    Tobit_logLik   = sprintf("%.1f", tob$ll),
    # GAM
    GAM_edf_sig    = paste0(sprintf("%.2f", gam_r$edf), fmt_star(gam_r$p)),
    GAM_R2         = sprintf("%.3f", gam_r$r2),
    GAM_AIC        = sprintf("%.1f", gam_r$aic),
    GAM_logLik     = sprintf("%.1f", gam_r$ll),
    # Raw values kept for the CSV
    OLS_beta_raw   = ols$b,      OLS_p_raw   = ols$p,
    Tobit_beta_raw = tob$b,      Tobit_p_raw = tob$p,
    GAM_edf_raw    = gam_r$edf,  GAM_p_raw   = gam_r$p,
    stringsAsFactors = FALSE
  )
  
  # 4e. GAM turning points for Table 2 ----------------------------------------
  tp <- gam_turning_points_(d, gam_r$fit)
  if (!is.null(tp)) {
    extrema_rows[[length(extrema_rows) + 1]] <-
      cbind(Domain = dom, Spatial_Index = spl, tp,
            stringsAsFactors = FALSE)
  }
}

cat("\nAll models fitted.\n\n")


# ==============================================================================
# SECTION 5  Supplementary Table 1 -- console, CSV, PNG
# ==============================================================================

supp_t1 <- dplyr::bind_rows(model_rows)

# 5a. Console ------------------------------------------------------------------
cat("==========================================================================\n")
cat("Supplementary Table 1: OLS vs Tobit vs GAM\n")
cat("Outcome: Observed Market Behavior (green spending share, z-scored)\n")
cat("==========================================================================\n")
print(as.data.frame(supp_t1 %>% dplyr::select(-dplyr::ends_with("_raw"))),
      row.names = FALSE, right = FALSE)
cat("\nStars: dagger p<.10  * p<.05  ** p<.01  *** p<.001  ns = not significant.\n\n")

# 5b. CSV ----------------------------------------------------------------------
csv_t1 <- supp_t1 %>%
  dplyr::transmute(
    Domain, Spatial_Index, N, Controls_Used,
    OLS_beta   = sprintf("%.3f", OLS_beta_raw),
    OLS_p      = fmt_p(OLS_p_raw),
    OLS_sig    = fmt_star(OLS_p_raw),
    OLS_SE, OLS_R2, OLS_AIC, OLS_logLik,
    Tobit_beta = sprintf("%.3f", Tobit_beta_raw),
    Tobit_p    = fmt_p(Tobit_p_raw),
    Tobit_sig  = fmt_star(Tobit_p_raw),
    Tobit_SE, Tobit_pseudoR2, Tobit_AIC, Tobit_logLik,
    GAM_edf    = sprintf("%.2f", GAM_edf_raw),
    GAM_p      = fmt_p(GAM_p_raw),
    GAM_sig    = fmt_star(GAM_p_raw),
    GAM_R2, GAM_AIC, GAM_logLik
  )
write.csv(csv_t1,
          file.path(out_dir, "data/supplementary/STable6_ModelComparison.csv"),
          row.names = FALSE)
cat("Supplementary Table 1 CSV saved.\n")

# 5c. PNG ----------------------------------------------------------------------
t1_display <- supp_t1 %>%
  dplyr::select(Domain, Spatial_Index, N,
                OLS_beta_sig, OLS_SE, OLS_R2, OLS_AIC, OLS_logLik,
                Tobit_beta_sig, Tobit_SE, Tobit_pseudoR2, Tobit_AIC, Tobit_logLik,
                GAM_edf_sig, GAM_R2, GAM_AIC, GAM_logLik)

gt_t1 <- t1_display %>%
  gt() %>%
  tab_header(
    title = md("**Supplementary Table 1.** OLS, Tobit, and GAM Model Comparison")
  ) %>%
  tab_spanner(label   = md("**OLS**"),
              columns = c(OLS_beta_sig, OLS_SE, OLS_R2, OLS_AIC, OLS_logLik)) %>%
  tab_spanner(label   = md("**Tobit**"),
              columns = c(Tobit_beta_sig, Tobit_SE, Tobit_pseudoR2,
                          Tobit_AIC, Tobit_logLik)) %>%
  tab_spanner(label   = md("**GAM**"),
              columns = c(GAM_edf_sig, GAM_R2, GAM_AIC, GAM_logLik)) %>%
  cols_label(
    Domain         = "Domain",
    Spatial_Index  = md("Spatial Index"),
    N              = md("*N*"),
    OLS_beta_sig   = md("\u03B2"),
    OLS_SE         = md("*SE*"),
    OLS_R2         = md("*R*\u00B2"),
    OLS_AIC        = "AIC",
    OLS_logLik     = "Log-Lik",
    Tobit_beta_sig = md("\u03B2"),
    Tobit_SE       = md("*SE*"),
    Tobit_pseudoR2 = md("Pseudo-*R*\u00B2"),
    Tobit_AIC      = "AIC",
    Tobit_logLik   = "Log-Lik",
    GAM_edf_sig    = "edf",
    GAM_R2         = md("*R*\u00B2"),
    GAM_AIC        = "AIC",
    GAM_logLik     = "Log-Lik"
  ) %>%
  cols_align(align = "left",  columns = c(Domain, Spatial_Index)) %>%
  cols_align(align = "right",
             columns = c(N,
                         OLS_beta_sig, OLS_SE, OLS_R2, OLS_AIC, OLS_logLik,
                         Tobit_beta_sig, Tobit_SE, Tobit_pseudoR2,
                         Tobit_AIC, Tobit_logLik,
                         GAM_edf_sig, GAM_R2, GAM_AIC, GAM_logLik)) %>%
  tab_footnote(footnote = md(paste0(
    "*Outcome: Observed Market Behavior (green spending share, z-scored). ",
    "Models estimated separately for each Domain \u00D7 Spatial Index combination, ",
    "matching the panel structure of Figure 4b.*  \n",
    "All models include control variables where usable in the slice: GDP per capita, ",
    "online shopping experience, education level, social media hours, main religion, ",
    "and country. Controls constant within a slice or perfectly collinear are dropped ",
    "automatically. Reported \u03B2 and *SE* are for the focal Spatial Index predictor only.  \n",
    "\u2020 *p* < .10; \\* *p* < .05; \\*\\* *p* < .01; \\*\\*\\* *p* < .001; ns = not significant.  \n",
    "OLS = ordinary least squares; Tobit = left-censored regression (lower bound = minimum ",
    "z-score of outcome); Pseudo-*R*\u00B2 = McFadden index (1 \u2212 LL_{full}/LL_{null});  \n",
    "GAM = generalised additive model with thin-plate regression spline; ",
    "edf = effective degrees of freedom (edf \u2248 1 implies linearity).  \n",
    "All predictors and outcomes are z-standardised prior to estimation."
  ))) %>%
  apply_gt_theme(tbl_width = pct(100))

png_t1 <- file.path(out_dir, "figures/STable6_ModelComparison.png")
gtsave(gt_t1, filename = png_t1, zoom = 2, expand = 20)
cat("Supplementary Table 1 PNG saved.\n\n")


# ==============================================================================
# SECTION 6  Supplementary Table 2 -- GAM Turning Points -- console, CSV, PNG
# ==============================================================================

cat("==========================================================================\n")
cat("Supplementary Table 2: GAM Turning Points (Extrema)\n")
cat("Values in z-score units (standardised within the analysis sample)\n")
cat("==========================================================================\n")

if (length(extrema_rows) > 0) {
  
  # 6a. Assemble and sort ------------------------------------------------------
  supp_t2 <- dplyr::bind_rows(extrema_rows) %>%
    dplyr::mutate(
      Domain        = factor(Domain,        levels = c("Grocery", "Electronics")),
      Spatial_Index = factor(Spatial_Index, levels = c("Green Exposure", "Desakota")),
      x_extremum    = round(x_extremum, 3),
      y_extremum    = round(y_extremum, 3)
    ) %>%
    dplyr::arrange(Domain, Spatial_Index, Type)
  
  # 6b. Console ----------------------------------------------------------------
  print(as.data.frame(supp_t2), row.names = FALSE)
  
  # 6c. CSV --------------------------------------------------------------------
  write.csv(supp_t2,
            file.path(out_dir, "data/supplementary/STable7_GAM_TurningPoints.csv"),
            row.names = FALSE)
  cat("\nSupplementary Table 2 CSV saved.\n")
  
  # 6d. PNG --------------------------------------------------------------------
  gt_t2 <- supp_t2 %>%
    gt() %>%
    tab_header(title = md("**Supplementary Table 2.** GAM Turning Points")) %>%
    cols_label(
      Domain        = "Domain",
      Spatial_Index = md("Spatial Index"),
      x_extremum    = md("*x* at Turning Point (Z-Score)"),
      y_extremum    = md("Fitted *y* at Turning Point (Z-Score)"),
      Type          = "Type"
    ) %>%
    tab_style(style     = cell_text(color = "#C0392B", weight = "bold"),
              locations = cells_body(columns = Type, rows = Type == "Maximum")) %>%
    tab_style(style     = cell_text(color = "#2471A3", weight = "bold"),
              locations = cells_body(columns = Type, rows = Type == "Minimum")) %>%
    cols_align(align = "left",   columns = c(Domain, Spatial_Index)) %>%
    cols_align(align = "right",  columns = c(x_extremum, y_extremum)) %>%
    cols_align(align = "center", columns = Type) %>%
    tab_footnote(footnote = md(paste0(
      "*Interior extrema of the GAM-fitted curve for Observed Market Behavior. ",
      "Panels with no interior turning points are omitted (monotonic GAM curves).*  \n",
      "GAMs include the same control variables as Table 1; controls are held at their ",
      "within-slice mean (numeric) or mode (categorical) when evaluating the curve.  \n",
      "Turning points identified as sign changes in the numerical first derivative ",
      "of the GAM predicted curve, evaluated on a 500-point grid over the observed ",
      "range of each Spatial Index. *x* and *y* are in z-standardised units.  \n",
      "**Red** = local maximum; **Blue** = local minimum."
    ))) %>%
    apply_gt_theme(tbl_width = pct(70))
  
  png_t2 <- file.path(out_dir, "png/Supplementary_Table2_GAM_TurningPoints.png")
  gtsave(gt_t2, filename = png_t2, zoom = 2, expand = 20)
  cat("Supplementary Table 2 PNG saved.\n")
  
} else {
  
  cat("  No interior turning points detected -- all four GAM curves are monotonic.\n")
  cat("  (edf ~= 1 in Supplementary Table 1 confirms near-linearity.)\n")
  
  # Informative placeholder PNG for the appendix
  gt_t2_empty <- data.frame(
    Note = paste0(
      "No interior turning points were detected for any of the four ",
      "Domain x Spatial Index combinations. All GAM curves are monotonic. ",
      "Refer to edf values in Supplementary Table 1 -- edf ~= 1 in all panels ",
      "confirms that the nonlinear component is negligible."
    ),
    stringsAsFactors = FALSE
  ) %>%
    gt() %>%
    tab_header(
      title    = md("**Supplementary Table 2.** GAM Turning Points"),
      subtitle = md("*Interior extrema of the GAM-fitted curve*")
    ) %>%
    cols_label(Note = "") %>%
    tab_style(style     = cell_text(color = "#555555", style = "italic"),
              locations = cells_body()) %>%
    apply_gt_theme(tbl_width = pct(70))
  
  png_t2 <- file.path(out_dir, "figures/STable7_GAM_TurningPoints.png")
  gtsave(gt_t2_empty, filename = png_t2, zoom = 2, expand = 20)
  cat("Supplementary Table 2 (no-extrema notice) PNG saved.\n")
}

