################################################################################
# Supp. Figure 2: LPM Parameter Sensitivity Analysis
#
# What it does:
#   Tests robustness of LPM cascade results by varying the two LPM parameters
#   (x0, k) at +/-10%, +/-20%, +/-30% of their baseline values.
#   Panel A: Envelope cascade showing baseline +/- sensitivity band
#            for Grocery and Electronic domains.
#   Panel B: Moran's I heatmap for Reporting Bias spatial clustering
#            across all (x0, k) combinations.
#
# Input:  data/benchmark-150city-130aggvars+sensitivity_49scenario.csv (wide-format)
#         data/MergedPanelV5.csv (for coordinates)
#         data/GeoIndexV6.xlsx (city lat/lon)
# Output: figures/SFig2_LPM_Sensitivity.png
#         figures/SFig2_LPM_Sensitivity.svg
#         data/supplementary/STable_LPM_Sensitivity.csv
################################################################################

rm(list=ls())

library(dplyr)
library(tidyverse)
library(patchwork)
library(scales)
library(sf)
library(spdep)
library(svglite)

################################################################################
## Reshape wide-format sensitivity CSV into long format
##
## Column naming convention in the wide file (49-scenario version):
##   - Baseline columns have NO suffix (e.g., greenSpendingShareElectronic_LPM)
##   - Sensitivity columns: {basevar}_x0{pct1}%_k{pct2}%
##     e.g. stdGreenWalkLikert_LPM_x080%_k130%
##   - Full 7×7 grid: x0 ∈ {70,80,90,100,110,120,130} × k ∈ same
##     minus the baseline (x0=100%, k=100%) = 48 combos + 1 baseline = 49
##
## Result: df_long with 150 cities × 49 scenarios = 7350 rows
##   120 base columns + x0, k (both as integer percentages)
################################################################################
df_wide <- read.csv("data/CityPanelSensitivity49Scenarios.csv",
                    check.names = FALSE)

# Harmonize city names: wide file uses spaces, other files use underscores
df_wide$city <- gsub(" ", "_", df_wide$city)

all_cols <- colnames(df_wide)

# Sensitivity columns: match _x0{pct}%_k{pct}% suffix
sens_cols <- grep("_x0[0-9]+%_k[0-9]+%$", all_cols, value = TRUE)
base_cols <- setdiff(all_cols, sens_cols)

# Parse each sensitivity column → base variable name, x0 pct, k pct
sens_parsed <- tibble(col = sens_cols) %>%
  mutate(
    base_var = sub("_x0[0-9]+%_k[0-9]+%$", "", col),
    x0_pct   = as.numeric(stringr::str_match(col, "_x0([0-9]+)%_k[0-9]+%$")[, 2]),
    k_pct    = as.numeric(stringr::str_match(col, "_k([0-9]+)%$")[, 2])
  )

# All unique (x0, k) combinations in the sensitivity columns
scenarios_grid <- sens_parsed %>%
  distinct(x0_pct, k_pct) %>%
  arrange(x0_pct, k_pct)

cat(sprintf("Found %d sensitivity (x0, k) combos and %d base vars\n",
            nrow(scenarios_grid), length(unique(sens_parsed$base_var))))

# ---- Helper: build one scenario by overwriting base columns ----
build_scenario <- function(x0_val, k_val) {
  sc_cols <- sens_parsed %>%
    filter(x0_pct == x0_val, k_pct == k_val)
  tmp <- df_wide[, base_cols, drop = FALSE]
  for (i in seq_len(nrow(sc_cols))) {
    bv <- sc_cols$base_var[i]
    sc <- sc_cols$col[i]
    if (bv %in% colnames(tmp)) tmp[[bv]] <- df_wide[[sc]]
  }
  tmp$x0 <- x0_val
  tmp$k  <- k_val
  tmp
}

# ---- Baseline: x0=100, k=100 (no suffix columns — use base columns as-is) ----
base_row_df <- df_wide[, base_cols, drop = FALSE]
base_row_df$x0 <- 100
base_row_df$k  <- 100

# ---- Build all 48 non-baseline scenarios ----
scenario_dfs <- lapply(seq_len(nrow(scenarios_grid)), function(i) {
  build_scenario(scenarios_grid$x0_pct[i], scenarios_grid$k_pct[i])
})

# ---- Combine: baseline + 48 scenarios = 49 total ----
df_long <- do.call(rbind, c(list(base_row_df), scenario_dfs))
df_long <- df_long[order(df_long$city, df_long$x0, df_long$k), ]

cat(sprintf("Wide:   %d rows x %d cols\n", nrow(df_wide), ncol(df_wide)))
cat(sprintf("Long:   %d rows x %d cols\n", nrow(df_long), ncol(df_long)))
cat(sprintf("Scenarios: %d (1 baseline + %d sensitivity)\n",
            nrow(scenarios_grid) + 1, nrow(scenarios_grid)))

# ── Load coordinates ─────────────────────────────────────────────────────────
df <- read.csv("data/MergedPanelV5.csv") %>%
  mutate(country = Country)

coords_matched <- readxl::read_excel("data/GeoIndexV6.xlsx") %>%
  mutate(country = Country, latitude = Latitude, longitude = Longitude) %>%
  dplyr::select(city, country, latitude, longitude)

# ── Output directory ─────────────────────────────────────���───────────────────
out_dir <- "figures"
dir.create(file.path(out_dir, "png"), showWarnings = FALSE, recursive = TRUE)


################################################################################
# 1. GRAPH THEME (consistent with Figure1.R)
################################################################################

theme_pub <- function(base_size = 7) {
  theme_minimal(base_size = base_size, base_family = "Arial") %+replace%
    theme(
      plot.title        = element_text(size = 8, face = "bold", hjust = 0,
                                       margin = ggplot2::margin(b = 2)),
      plot.subtitle     = element_text(size = 6.5, color = "grey35", hjust = 0,
                                       margin = ggplot2::margin(b = 3)),
      axis.title        = element_text(size = 7, face = "plain"),
      axis.text         = element_text(size = 6, color = "grey20"),
      axis.ticks        = element_line(linewidth = 0.3, color = "grey50"),
      axis.ticks.length = unit(1.5, "pt"),
      axis.line         = element_line(linewidth = 0.35, color = "grey30"),
      panel.grid.major  = element_blank(),
      panel.grid.minor  = element_blank(),
      legend.title      = element_text(size = 6.5, face = "bold"),
      legend.text       = element_text(size = 6),
      legend.key.size   = unit(0.3, "cm"),
      legend.margin     = ggplot2::margin(0, 0, 0, 0),
      legend.position   = "bottom",
      strip.text        = element_blank(),
      strip.background  = element_blank(),
      plot.margin       = ggplot2::margin(4, 4, 4, 4)
    )
}


################################################################################
# 2. IDENTIFY BASELINE AND SENSITIVITY GRID
################################################################################

# Each unique (x0, k) pair is one scenario; values are integer percentages
scenarios <- df_long %>%
  distinct(x0, k) %>%
  arrange(x0, k)

cat(sprintf("Found %d unique (x0, k) scenarios in the sensitivity dataset.\n",
            nrow(scenarios)))

# Baseline is x0=100, k=100 (100% of original = no perturbation)
x0_baseline <- 100
k_baseline  <- 100

cat(sprintf("Unique x0 values: %s\n", paste(sort(unique(df_long$x0)), collapse = ", ")))
cat(sprintf("Unique k  values: %s\n", paste(sort(unique(df_long$k)),  collapse = ", ")))

# Compute perturbation labels relative to baseline
scenarios <- scenarios %>%
  mutate(
    x0_pct = (x0 - x0_baseline) / x0_baseline,
    k_pct  = (k  - k_baseline)  / k_baseline,
    x0_label = sprintf("%+.0f%%", x0_pct * 100),
    k_label  = sprintf("%+.0f%%", k_pct  * 100)
  )

# Merge perturbation labels back to df_long
df_long <- df_long %>%
  left_join(scenarios, by = c("x0", "k"))

# Ordered factor labels for heatmap axes
x0_label_levels <- scenarios %>% arrange(x0_pct) %>% pull(x0_label) %>% unique()
k_label_levels  <- scenarios %>% arrange(k_pct)  %>% pull(k_label)  %>% unique()


################################################################################
# 3. MERGE COORDINATES INTO SENSITIVITY DATA
################################################################################

df_long <- df_long %>%
  left_join(coords_matched, by = c("city", "country"))


################################################################################
# 4. COMPUTE CASCADE MEANS AND MORAN'S I FOR EVERY SCENARIO
################################################################################

# Helper: compute one scenario's cascade + Moran's I for a given domain
#
# Cascade means use ALL cities with complete LPM data (no coords required),
# matching the Figure1.R sample. Moran's I uses the spatial subset with coords.
compute_scenario <- function(data_scenario, domain) {

  suffix <- domain
  var_likert   <- paste0("stdGreen", suffix, "Likert_LPM")
  var_report   <- paste0("reportMonthlyGreen", suffix, "_LPM")
  var_observed <- paste0("greenSpendingShare", suffix, "_LPM")

  # Full sample for cascade means (no coords needed — matches Figure1 logic)
  d_all <- data_scenario %>%
    dplyr::select(city, country,
                  all_of(c(var_likert, var_report, var_observed))) %>%
    rename(Intention = !!sym(var_likert),
           Reported  = !!sym(var_report),
           Observed  = !!sym(var_observed)) %>%
    filter(complete.cases(.))

  # Regional cascade averages
  cascade_mean <- d_all %>%
    summarise(
      Intention = mean(Intention, na.rm = TRUE),
      Reported  = mean(Reported,  na.rm = TRUE),
      Observed  = mean(Observed,  na.rm = TRUE)
    )

  # Country-level cascade averages
  cascade_country <- d_all %>%
    group_by(country) %>%
    summarise(
      Intention = mean(Intention, na.rm = TRUE),
      Reported  = mean(Reported,  na.rm = TRUE),
      Observed  = mean(Observed,  na.rm = TRUE),
      .groups   = "drop"
    )

  # Spatial subset for Moran's I (requires coords)
  d_geo <- data_scenario %>%
    dplyr::select(city, country, latitude, longitude,
                  all_of(c(var_likert, var_report, var_observed))) %>%
    rename(Intention = !!sym(var_likert),
           Reported  = !!sym(var_report),
           Observed  = !!sym(var_observed)) %>%
    filter(complete.cases(.)) %>%
    mutate(Gap2_SayDo = Reported - Observed)

  # Moran's I
  moran_I <- NA_real_
  moran_p <- NA_real_

  if (nrow(d_geo) >= 5) {
    tryCatch({
      coords_mat  <- as.matrix(d_geo[, c("longitude", "latitude")])
      knn_weights <- spdep::knearneigh(coords_mat, k = min(5, nrow(d_geo) - 1))
      nb          <- spdep::knn2nb(knn_weights)
      weights     <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
      mtest       <- spdep::moran.test(d_geo$Gap2_SayDo, weights,
                                       zero.policy = TRUE)
      moran_I     <- mtest$estimate[1]
      moran_p     <- mtest$p.value
    }, error = function(e) {
      message("Moran's I failed for scenario: ", e$message)
    })
  }

  list(
    cascade_mean    = cascade_mean,
    cascade_country = cascade_country,
    moran_I         = moran_I,
    moran_p         = moran_p
  )
}


# ── Main loop over all scenarios ─────────────────────────────────────────────

results_list <- list()
scenario_keys <- scenarios %>% dplyr::select(x0, k, x0_pct, k_pct, x0_label, k_label)

cat(sprintf("Running %d sensitivity scenarios...\n", nrow(scenario_keys)))

for (row_i in seq_len(nrow(scenario_keys))) {
  
  sk <- scenario_keys[row_i, ]
  data_s <- df_long %>% filter(x0 == sk$x0, k == sk$k)
  
  for (dom in c("Grocery", "Electronic")) {
    
    res <- compute_scenario(data_s, dom)
    
    results_list[[length(results_list) + 1]] <- tibble(
      x0_pct    = sk$x0_pct,
      k_pct     = sk$k_pct,
      x0_label  = sk$x0_label,
      k_label   = sk$k_label,
      x0_value  = sk$x0,
      k_value   = sk$k,
      domain    = dom,
      Intention = res$cascade_mean$Intention,
      Reported  = res$cascade_mean$Reported,
      Observed  = res$cascade_mean$Observed,
      Gap1_SaySay       = res$cascade_mean$Intention - res$cascade_mean$Reported,
      Gap2_SayDo        = res$cascade_mean$Reported  - res$cascade_mean$Observed,
      Total_Attrition_Pct = (1 - res$cascade_mean$Observed /
                               res$cascade_mean$Intention) * 100,
      moran_I   = res$moran_I,
      moran_p   = res$moran_p
    )
  }
  
  if (row_i %% 10 == 0)
    cat(sprintf("  ... completed %d / %d scenarios\n", row_i, nrow(scenario_keys)))
}

results_df <- bind_rows(results_list)
cat(sprintf("Done. %d rows in results table.\n", nrow(results_df)))

# Identify baseline rows
results_baseline <- results_df %>% filter(x0_pct == 0 & k_pct == 0)


################################################################################
# 5. PANEL A — ENVELOPE CASCADE
#
# For each domain: bold baseline cascade with shaded min-max envelope
# across all (x0, k) scenarios.
################################################################################

# Pivot to long format for ribbon
results_long <- results_df %>%
  pivot_longer(cols = c(Intention, Reported, Observed),
               names_to = "Stage", values_to = "Score") %>%
  mutate(Stage = factor(Stage, levels = c("Intention", "Reported", "Observed")))

# Envelope bounds
envelope_df <- results_long %>%
  group_by(domain, Stage) %>%
  summarise(
    ymin = min(Score, na.rm = TRUE),
    ymax = max(Score, na.rm = TRUE),
    .groups = "drop"
  )

baseline_long <- results_baseline %>%
  pivot_longer(cols = c(Intention, Reported, Observed),
               names_to = "Stage", values_to = "Score") %>%
  mutate(Stage = factor(Stage, levels = c("Intention", "Reported", "Observed")))

cascade_envelope <- envelope_df %>%
  left_join(baseline_long %>% dplyr::select(domain, Stage, Score),
            by = c("domain", "Stage")) %>%
  rename(baseline = Score) %>%
  mutate(x_num = as.numeric(Stage))


# ── Build one envelope panel per domain ──────────────────────────────────────

make_envelope_panel <- function(dom, panel_label, show_y = TRUE) {
  
  d <- cascade_envelope %>% filter(domain == dom)
  
  # Attrition stats
  base_intention <- d$baseline[d$Stage == "Intention"]
  base_observed  <- d$baseline[d$Stage == "Observed"]
  base_attrition <- (1 - base_observed / base_intention) * 100
  
  dom_res <- results_df %>% filter(domain == dom)
  min_attrition <- min(dom_res$Total_Attrition_Pct, na.rm = TRUE)
  max_attrition <- max(dom_res$Total_Attrition_Pct, na.rm = TRUE)
  
  p <- ggplot(d, aes(x = x_num)) +
    # Shaded envelope
    geom_ribbon(aes(ymin = ymin, ymax = ymax),
                fill = "#1b9e77", alpha = 0.20) +
    # Baseline bold line
    geom_line(aes(y = baseline), color = "black", linewidth = 0.9) +
    geom_point(aes(y = baseline), color = "black", size = 2.2, shape = 21,
               fill = "white", stroke = 1.1) +
    # Baseline value labels
    geom_text(aes(y = baseline, label = sprintf("%.3f", baseline)),
              vjust = -1.5, fontface = "bold", color = "black", size = 2.8) +
    # Envelope boundary labels at Observed stage
    geom_text(data = d %>% filter(Stage == "Observed"),
              aes(x = x_num, y = ymin, label = sprintf("%.3f", ymin)),
              vjust = 1.8, color = "#1b9e77", size = 2.2, fontface = "italic") +
    geom_text(data = d %>% filter(Stage == "Observed"),
              aes(x = x_num, y = ymax, label = sprintf("%.3f", ymax)),
              vjust = -0.8, color = "#1b9e77", size = 2.2, fontface = "italic") +
    scale_x_continuous(breaks = 1:3,
                       labels = c("Intention", "Reported", "Observed")) +
    scale_y_continuous(limits = c(0, 1.05), breaks = seq(0, 1, 0.2),
                       labels = percent_format(accuracy = 1)) +
    labs(
      title = sprintf("%s  LPM — %s", panel_label, dom),
      y     = if (show_y) "Score" else NULL
    ) +
    theme_pub() +
    theme(
      axis.title.x = element_blank(),
      plot.margin  = ggplot2::margin(4, 6, 4, 6)
    )
  
  if (!show_y) {
    p <- p + theme(axis.title.y = element_blank())
  }
  
  p
}

panel_A1 <- make_envelope_panel("Grocery",    "a.", show_y = TRUE)
panel_A2 <- make_envelope_panel("Electronic", "b.", show_y = FALSE)

panel_A <- (panel_A1 | panel_A2) +
  plot_layout(widths = c(1, 1))



################################################################################
# 6. PANEL B — MORAN'S I HEATMAP
#
# 2D grid: x-axis = x0 perturbation, y-axis = k perturbation
# Fill = Moran's I value; significance overlay
################################################################################

make_heatmap_panel <- function(dom, panel_label) {
  
  d <- results_df %>%
    filter(domain == dom) %>%
    mutate(
      x0_fct = factor(x0_label, levels = x0_label_levels),
      k_fct  = factor(k_label,  levels = rev(k_label_levels)),
      sig    = case_when(
        moran_p < 0.001 ~ "***",
        moran_p < 0.01  ~ "**",
        moran_p < 0.05  ~ "*",
        TRUE            ~ ""
      ),
      # Combine coefficient and stars into one label (value on top, stars below)
      cell_label = paste0(sprintf("%.3f", moran_I),
                          ifelse(sig == "", "", paste0("\n", sig))),
      is_baseline = (x0_pct == 0 & k_pct == 0)
    )
  
  ggplot(d, aes(x = x0_fct, y = k_fct)) +
    geom_tile(aes(fill = moran_I), color = "grey70", linewidth = 0.4) +
    # Combined label: coefficient + significance stars — always black
    geom_text(aes(label = cell_label), size = 2, color = "black",
              fontface = "bold", lineheight = 0.85) +
    # Highlight baseline cell
    geom_tile(data = d %>% filter(is_baseline),
              aes(x = x0_fct, y = k_fct),
              fill = NA, color = "#D62728", linewidth = 1.2) +
    scale_fill_gradient(
      low  = "#DEEBF7", high = "#2171B5",
      name = "Moran's I",
      guide = guide_colorbar(
        title.position = "top", title.hjust = 0.5,
        barwidth = 8, barheight = 0.5)
    ) +
    labs(
      title = sprintf("%s  Moran's I — Reporting Bias (%s)", panel_label, dom),
      x     = expression(x[0] ~ " perturbation"),
      y     = expression(k ~ " perturbation")
    ) +
    theme_pub() +
    theme(
      axis.title.x    = element_text(size = 7),
      axis.title.y    = element_text(size = 7),
      axis.text.x     = element_text(size = 5.5, angle = 0),
      axis.text.y     = element_text(size = 5.5),
      legend.position = "bottom",
      panel.grid      = element_blank(),
      plot.margin     = ggplot2::margin(4, 6, 4, 6)
    )
}

panel_B1 <- make_heatmap_panel("Grocery",    "c.")
panel_B2 <- make_heatmap_panel("Electronic", "d.")

panel_B <- (panel_B1 | panel_B2) +
  plot_layout(widths = c(1, 1))




################################################################################
# 7. COMPOSE & SAVE SUPPLEMENTARY FIGURE
################################################################################

composite <- (panel_A / panel_B) +
  plot_layout(heights = c(0.45, 0.55)) 
  # +plot_annotation(
  #   title    = "Supplementary Figure: LPM Parameter Sensitivity Analysis",
  #   subtitle = paste0(
  #     "Panels a\u2013b: Cascade envelope across all (x\u2080, k) scenarios ",
  #     "(\u00b110%, \u00b120%, \u00b130%). Shaded band = min\u2013max range; ",
  #     "bold line = baseline.\n",
  #     "Panels c\u2013d: Moran\u2019s I heatmap for Reporting Bias spatial clustering. ",
  #     "Red border = baseline. * p<0.05, ** p<0.01, *** p<0.001."
  #   ),
  #   theme = theme(
  #     plot.title    = element_text(size = 9, face = "bold", family = "Arial"),
  #     plot.subtitle = element_text(size = 6.5, color = "grey35", family = "Arial",
  #                                  lineheight = 1.3),
  #     plot.margin   = ggplot2::margin(6, 4, 6, 4)
  #   )
  # )

print(composite)

# Save outputs
ggsave(file.path("data/supplementary", "SFig2_LPM_Sensitivity.png"),
       composite, width = 180, height = 200, units = "mm",
       dpi = 600, bg = "white")

dir.create(file.path(out_dir, "svg"), showWarnings = FALSE, recursive = TRUE)
ggsave(file.path(out_dir, "SFig2_LPM_Sensitivity.svg"),
       composite, width = 180, height = 200, units = "mm",
       device = svglite, bg = "white")

cat("Supplementary figure saved.\n")


################################################################################
# 8. SUPPLEMENTARY TABLE: FULL SENSITIVITY RESULTS
################################################################################

results_export <- results_df %>%
  mutate(
    sig_label = case_when(
      moran_p < 0.001 ~ "***",
      moran_p < 0.01  ~ "**",
      moran_p < 0.05  ~ "*",
      TRUE            ~ "n.s."
    )
  ) %>%
  dplyr::select(
    domain, x0_pct, k_pct, x0_value, k_value,
    Intention, Reported, Observed,
    Gap1_SaySay, Gap2_SayDo, Total_Attrition_Pct,
    moran_I, moran_p, sig_label
  ) %>%
  arrange(domain, x0_pct, k_pct)

write.csv(results_export,
          file.path(out_dir, "STable_LPM_Sensitivity.csv"),
          row.names = FALSE)

cat("Supplementary table saved.\n")


################################################################################
# 9. SUMMARY STATISTICS (printed to console)
################################################################################

cat("\n================================================================\n")
cat("SENSITIVITY ANALYSIS SUMMARY\n")
cat("================================================================\n\n")

for (dom in c("Grocery", "Electronic")) {
  d <- results_df %>% filter(domain == dom)
  b <- d %>% filter(x0_pct == 0 & k_pct == 0)
  
  cat(sprintf("-- %s -----------------------------------------\n", dom))
  cat(sprintf("  Baseline:  Intention=%.3f  Reported=%.3f  Observed=%.3f\n",
              b$Intention, b$Reported, b$Observed))
  cat(sprintf("  Baseline Attrition: %.1f%%\n", b$Total_Attrition_Pct))
  cat(sprintf("  Attrition range:    [%.1f%% - %.1f%%]\n",
              min(d$Total_Attrition_Pct), max(d$Total_Attrition_Pct)))
  cat(sprintf("  Baseline Moran's I: %.4f (p = %.4f)\n",
              b$moran_I, b$moran_p))
  cat(sprintf("  Moran's I range:    [%.4f - %.4f]\n",
              min(d$moran_I, na.rm = TRUE), max(d$moran_I, na.rm = TRUE)))
  n_sig <- sum(d$moran_p < 0.05, na.rm = TRUE)
  cat(sprintf("  Significant (p<0.05): %d / %d scenarios (%.0f%%)\n\n",
              n_sig, nrow(d), n_sig / nrow(d) * 100))
}

cat("================================================================\n")
cat("DONE.\n")




