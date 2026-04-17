################################################################################
# Figure 4: Spatial Exposure Effects — Forest Plot & Scatter Fits
#
# What it does:
#   Panel 4a: Forest plot of LPM regression coefficients from mediation
#     analysis (Total / Direct / Indirect effects via nature connectedness).
#     Color = spatial index (Green Exposure vs Desakota).
#     Shape = domain (Grocery vs Electronics).
#   Panel 4b: Scatter plots with OLS (dotted) and GAM (solid) fit lines
#     for Grocery (left) and Electronics (right).
#
# Input:  data/IncludingLogData.csv
# Output: figures/Figure4_FE.png, figures/Figure4_FE.svg
#
# Dependency: Run STable18_tranformation.R first (generates input CSV).
################################################################################

rm(list = ls())

# ── Packages ──────────────────────────────────────────────────────────────────
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
library(mgcv)
library(boot)

# ── Colour palette ─────────────────────────────────────────────────────────────
col_green    <- "#2E8B57"   # Green Exposure  (forest green)
col_desakota <- "#E07B3A"   # Desakota        (warm orange)

# ══════════════════════════════════════════════════════════════════════════════
# DATA LOADING
# ══════════════════════════════════════════════════════════════════════════════

df <- read.csv("data/IncludingLogData.csv") %>%
  mutate(country = Country)

df_gaps <- df %>%
  mutate(
    Gap1_Grocery_LPM     = stdGreenGroceryLikert_LPM     - reportMonthlyGreenGrocery_LPM,
    Gap2_Grocery_LPM     = reportMonthlyGreenGrocery_LPM - greenSpendingShareGrocery_LPM,
    Gap1_Electronic_LPM  = stdGreenElectronicLikert_LPM  - reportMonthlyGreenElectronic_LPM,
    Gap2_Electronic_LPM  = reportMonthlyGreenElectronic_LPM - greenSpendingShareElectronic_LPM
  )

controls     <- c("GDP_per", "onlineShoppingExperience", "isHighEdu", "socialMediaHrs","Main.religion", "country")
med_var      <- "genGreenConnectness"
spatial_vars <- c("Desakota_Index_CropOnly_log", "Green.Exposure.Index")

outcome_vars_all <- c(
  "Gap1_Grocery_LPM", "Gap2_Grocery_LPM",
  "Gap1_Electronic_LPM", "Gap2_Electronic_LPM",
  "greenSpendingShareGrocery_LPM", "greenSpendingShareElectronic_LPM"
)
meta_vars <- c("city", "country", "isCapitalCity","Main.religion")

all_needed <- unique(c(
  meta_vars, controls, spatial_vars, med_var,
  outcome_vars_all,
  "Blue.Exposure.Index", "Desakota_Index_CropAndGreen_log"
))

df_clean <- df_gaps %>%
  dplyr::select(all_of(all_needed)) %>%
  tidyr::drop_na()

cols_to_z    <- setdiff(all_needed, meta_vars)
df_z         <- df_clean
df_z[cols_to_z] <- lapply(df_z[cols_to_z], function(x) as.numeric(scale(x)))

# ══════════════════════════════════════════════════════════════════════════════
# PANEL 4a —  Plot 
# ══════════════════════════════════════════════════════════════════════════════

# ── Helpers ───────────────────────────────────────────────────────────────────

# Star labels from p-value
sig_stars <- function(p) {
  ifelse(p < 0.001, "***", ifelse(p < 0.01, "**", ifelse(p < 0.05, "*", "ns")))
}

# Build one row for the forest-plot data frame
make_row <- function(label, effect_type, domain, exposure,
                     beta, lower, upper, p) {
  data.frame(
    Label      = label,
    EffectType = effect_type,
    Domain     = domain,
    Exposure   = exposure,
    beta       = beta,
    Lower      = lower,
    Upper      = upper,
    p          = p,
    Sig        = sig_stars(p),
    stringsAsFactors = FALSE
  )
}

# Baron & Kenny mediation for one spatial predictor / outcome combination.
# Returns three rows: Total Effect (c), Direct Effect (c'), Indirect Effect (a*b).
# Indirect effect CI and p-value use percentile bootstrap (n_boot resamples).
mediation_rows <- function(data, y_var, x_var, m_var, controls,
                           label, domain, exposure,
                           n_boot = 1000, seed = 42) {

  vars_needed <- c(y_var, x_var, m_var, controls)
  d <- data %>% dplyr::select(all_of(vars_needed)) %>% tidyr::drop_na()
  if (nrow(d) < 20) return(NULL)

  ctrl_rhs <- paste(controls, collapse = " + ")

  # ── Path c  : Outcome ~ Spatial + Controls  (Total Effect) ──────────────────
  fit_c  <- lm(as.formula(paste(y_var, "~", x_var, "+", ctrl_rhs)), data = d)
  cf_c   <- coef(summary(fit_c))
  c_est  <- cf_c[x_var, "Estimate"]
  c_se   <- cf_c[x_var, "Std. Error"]
  c_p    <- cf_c[x_var, "Pr(>|t|)"]

  # ── Path a  : Mediator ~ Spatial + Controls ──────────────────────────────────
  fit_a  <- lm(as.formula(paste(m_var, "~", x_var, "+", ctrl_rhs)), data = d)
  cf_a   <- coef(summary(fit_a))
  a_est  <- cf_a[x_var, "Estimate"]

  # ── Path c' & b : Outcome ~ Spatial + Mediator + Controls  (Direct Effect) ──
  fit_cp <- lm(as.formula(paste(y_var, "~", x_var, "+", m_var, "+", ctrl_rhs)),
               data = d)
  cf_cp  <- coef(summary(fit_cp))
  cp_est <- cf_cp[x_var,  "Estimate"]
  cp_se  <- cf_cp[x_var,  "Std. Error"]
  cp_p   <- cf_cp[x_var,  "Pr(>|t|)"]
  b_est  <- cf_cp[m_var,  "Estimate"]

  # ── Indirect Effect (a * b) — bootstrap percentile CI ───────────────────────
  boot_indirect <- function(dat, idx) {
    db   <- dat[idx, ]
    a_b  <- coef(lm(as.formula(paste(m_var, "~", x_var, "+", ctrl_rhs)), data = db))[x_var]
    b_b  <- coef(lm(as.formula(paste(y_var, "~", x_var, "+", m_var, "+", ctrl_rhs)),
                    data = db))[m_var]
    a_b * b_b
  }

  set.seed(seed)
  bt      <- boot::boot(data = d, statistic = boot_indirect, R = n_boot)
  bt_ci   <- boot::boot.ci(bt, type = "perc", conf = 0.95)$percent[4:5]  # [lower, upper]
  ab_est  <- a_est * b_est
  # Two-sided p-value: proportion of bootstrap resamples on the opposite side of 0
  ab_p    <- 2 * min(mean(bt$t >= 0), mean(bt$t <= 0))
  ab_p    <- max(ab_p, 1 / n_boot)   # floor at 1/n_boot

  list(
    total    = make_row(label, "Total Effects",
                        domain, exposure,
                        c_est, c_est - 1.96 * c_se, c_est + 1.96 * c_se, c_p),
    direct   = make_row(label, "Direct Effect\n(indep. of NC)",
                        domain, exposure,
                        cp_est, cp_est - 1.96 * cp_se, cp_est + 1.96 * cp_se, cp_p),
    indirect = make_row(label, "Indirect Effect\n(via NC)",
                        domain, exposure,
                        ab_est, bt_ci[1], bt_ci[2], ab_p)
  )
}

# ── Build all rows ─────────────────────────────────────────────────────────────
#
# Three horizontal categories (columns in the forest plot):
#   "Reported Gap"                     = Gap1 (attitude → self-report)
#   "Reporting Bias\n(Green Illusion)" = Gap2 (self-report → observed)
#   "Observed Market\nBehavior"        = greenSpendingShare
#
# Three vertical effect types (rows in the forest plot):
#   "Total Effects"                = Path c  : Outcome ~ Spatial + Controls
#   "Direct Effect\n(indep. of NC)"= Path c' : Outcome ~ Spatial + NC + Controls
#   "Indirect Effect\n(via NC)"    = a × b   : bootstrapped product of paths a and b
#
# Two spatial predictors × Two domains = 4 blocks per cell

rows <- list()

for (domain in c("Grocery", "Electronics")) {

  suf <- if (domain == "Grocery") "Grocery" else "Electronic"

  outcome_map <- list(
    "Reported Gap"                      = paste0("Gap1_", suf, "_LPM"),
    "Reporting Bias\n(Green Illusion)"  = paste0("Gap2_", suf, "_LPM"),
    "Observed Market\nBehavior"         = paste0("greenSpendingShare", suf, "_LPM")
  )

  for (cat_label in names(outcome_map)) {
    y_var <- outcome_map[[cat_label]]

    for (sp in c("Green.Exposure.Index", "Desakota_Index_CropOnly_log")) {
      expo_name <- if (sp == "Green.Exposure.Index") "Green Exposure" else "Desakota"

      res <- mediation_rows(
        data     = df_z,
        y_var    = y_var,
        x_var    = sp,
        m_var    = med_var,
        controls = controls,
        label    = cat_label,
        domain   = domain,
        exposure = expo_name
      )

      if (!is.null(res)) {
        rows[[length(rows) + 1]] <- res$total
        rows[[length(rows) + 1]] <- res$direct
        rows[[length(rows) + 1]] <- res$indirect
      }
    }
  }
}

fp_df <- bind_rows(rows) %>% filter(!is.na(beta))

# ── Factor ordering ───────────────────────────────────────────────────────────

fp_df$HorizCat <- factor(
  fp_df$Label,
  levels = c(
    "Reported Gap",
    "Reporting Bias\n(Green Illusion)",
    "Observed Market\nBehavior"
  )
)

fp_df$EffectType <- factor(
  fp_df$EffectType,
  levels = c(
    "Total Effects",
    "Direct Effect\n(indep. of NC)",
    "Indirect Effect\n(via NC)"
  )
)

fp_df$Domain <- factor(fp_df$Domain, levels = c("Grocery", "Electronics"))

# For shape: Grocery = circle (16), Electronics = triangle (17)
fp_df$ShapeKey <- ifelse(fp_df$Domain == "Grocery", "Grocery", "Electronics")
fp_df$ShapeKey <- factor(fp_df$ShapeKey, levels = c("Grocery", "Electronics"))

# Fix 2 & 3: Order within each EffectType block:
#   Green Exposure, Grocery → Green Exposure, Electronics →
#   Desakota, Grocery      → Desakota, Electronics
# Then build clean y-axis labels (no repeated EffectType prefix)
fp_df$Exposure <- factor(fp_df$Exposure, levels = c("Green Exposure", "Desakota"))

fp_df <- fp_df %>%
  arrange(EffectType, Exposure, Domain) %>%
  mutate(
    # Clean label: "Green Exposure, Grocery" / "Green Exposure, Electronics" /
    #              "Desakota, Grocery"       / "Desakota, Electronics"
    YLabel = paste0(as.character(Exposure), ", ", as.character(Domain)),
    # Unique key preserving order
    YKey   = paste0(as.character(EffectType), "__",
                    as.character(Exposure), "__",
                    as.character(Domain))
  )

# Preserve display order as factor (top = first EffectType, last entry = bottom)
# ggplot plots factors bottom-up, so we reverse
ykey_ordered <- fp_df %>%
  dplyr::select(EffectType, Exposure, Domain, YKey, YLabel) %>%
  distinct() %>%
  arrange(EffectType, Exposure, Domain) %>%
  pull(YKey)

fp_df$YKey <- factor(fp_df$YKey, levels = rev(ykey_ordered))

# Build named vector for scale_y_discrete labels (YKey → YLabel)
ylabel_map <- fp_df %>%
  dplyr::select(YKey, YLabel) %>%
  distinct() %>%
  tibble::deframe()

# p-value label
fp_df$pLabel <- paste0("β=", formatC(fp_df$beta, format="f", digits=2), fp_df$Sig)

# ── Theme ──────────────────────────────────────────────────────────────────────
theme_fig4 <- function(base_size = 7) {
  theme_classic(base_family = "Helvetica", base_size = base_size) %+replace%
    theme(
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      panel.grid       = element_blank(),
      axis.line        = element_line(colour = "black", linewidth = 0.4),
      axis.ticks       = element_line(colour = "black", linewidth = 0.3),
      axis.title       = element_text(size = 6.5, colour = "black", face = "plain"),
      axis.text        = element_text(size = 6, colour = "black"),
      strip.text       = element_text(size = 7, face = "bold", colour = "black"),
      strip.background = element_rect(fill = "grey94", colour = "grey70"),
      legend.title     = element_text(size = 6.5, face = "bold"),
      legend.text      = element_text(size = 6),
      legend.key.size  = unit(3, "mm"),
      legend.background = element_rect(fill = NA, colour = NA),
      plot.title       = element_text(size = 8, face = "bold", hjust = 0,
                                      margin = ggplot2::margin(b = 3)),
      plot.margin      = ggplot2::margin(5, 5, 5, 5, "pt")
    )
}

# ── Build Panel 4a ─────────────────────────────────────────────────────────────

panel4a <- ggplot(fp_df,
                  aes(x     = beta,
                      y     = YKey,
                      colour = Exposure,
                      shape  = ShapeKey)) +
  
  geom_vline(xintercept = 0, linetype = "dashed",
             colour = "grey50", linewidth = 0.35) +
  
  geom_errorbarh(aes(xmin = Lower, xmax = Upper),
                 height = 0.35, linewidth = 0.45) +
  
  geom_point(size = 2.4) +
  
  geom_text(aes(label = pLabel, x = Upper + 0.005),
            hjust = 0, size = 1.7, show.legend = FALSE) +
  
  # Horizontal categories → columns
  facet_grid(EffectType ~ HorizCat, scales = "free_y", space = "free_y") +
  
  scale_colour_manual(
    values = c("Green Exposure" = col_green, "Desakota" = col_desakota),
    name   = "Spatial Index"
  ) +
  scale_shape_manual(
    values = c("Grocery" = 16, "Electronics" = 17),
    name   = "Domain"
  ) +
  
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.22))) +
  scale_y_discrete(labels = ylabel_map) +
  
  labs(title = "a",
       x = "Regression Coefficient (β)",
       y = "Spatial Index, Domain") +
  
  theme_fig4() +
  theme(
    axis.text.y     = element_text(size = 5.5),
    axis.title.x    = element_text(size = 6.5, face = "plain",
                                   margin = ggplot2::margin(t = 4)),
    axis.title.y    = element_text(size = 6.5, face = "plain", angle = 90,
                                   margin = ggplot2::margin(r = 4)),
    legend.position = "bottom",
    legend.box      = "horizontal",
    legend.margin   = ggplot2::margin(2, 0, 0, 0)
  )


# ══════════════════════════════════════════════════════════════════════════════
# PANEL 4b — Scatter + OLS/GAM fits (Grocery | Electronics side by side)
# ══════════════════════════════════════════════════════════════════════════════

# ── Reshape long: one row per obs × domain × spatial index ─────────────────

df_long_out <- df_z %>%
  pivot_longer(
    cols      = c(greenSpendingShareGrocery_LPM, greenSpendingShareElectronic_LPM),
    names_to  = "Domain_raw",
    values_to = "Actual_Market_Behavior"
  ) %>%
  mutate(
    Domain = case_when(
      Domain_raw == "greenSpendingShareGrocery_LPM"    ~ "Grocery",
      Domain_raw == "greenSpendingShareElectronic_LPM" ~ "Electronics"
    ),
    Domain = factor(Domain, levels = c("Grocery", "Electronics"))
  )

df_plot_b <- df_long_out %>%
  pivot_longer(
    cols      = c(Desakota_Index_CropOnly_log, Green.Exposure.Index),
    names_to  = "Spatial_raw",
    values_to = "Spatial_Value"
  ) %>%
  mutate(
    SpatialLabel = case_when(
      Spatial_raw == "Desakota_Index_CropOnly_log" ~ "Desakota",
      Spatial_raw == "Green.Exposure.Index"        ~ "Green Exposure"
    ),
    SpatialLabel = factor(SpatialLabel, levels = c("Green Exposure", "Desakota"))
  )

# ── Build annotation data (OLS β + GAM R²) ────────────────────────────────────

annot_b_list <- list()
idx <- 1

for (dom in c("Grocery", "Electronics")) {
  for (sp_lbl in c("Green Exposure", "Desakota")) {
    
    d_sub <- df_plot_b %>%
      filter(Domain == dom, SpatialLabel == sp_lbl)
    
    fit_ols <- lm(Actual_Market_Behavior ~ Spatial_Value, data = d_sub)
    fit_gam <- gam(Actual_Market_Behavior ~ s(Spatial_Value, bs = "tp"), data = d_sub)
    
    s_ols <- summary(fit_ols)
    s_gam <- summary(fit_gam)
    
    beta_ols <- s_ols$coefficients[2, 1]
    p_ols    <- s_ols$coefficients[2, 4]
    r2_ols   <- s_ols$r.squared
    r2_gam   <- s_gam$r.sq
    edf_gam  <- s_gam$s.table[1, "edf"]
    p_gam    <- s_gam$s.table[1, "p-value"]
    
    star <- function(p) ifelse(p < 0.001, "***", ifelse(p < 0.01, "**", ifelse(p < 0.05, "*", "")))
    
    x_range <- range(d_sub$Spatial_Value,         na.rm = TRUE)
    y_range <- range(d_sub$Actual_Market_Behavior, na.rm = TRUE)
    x_span  <- diff(x_range)
    y_span  <- diff(y_range)
    
    # Fix 5: Green Exposure → bottom-right (hjust=1, vjust=0)
    #         Desakota      → top-left    (hjust=0, vjust=1)
    if (sp_lbl == "Green Exposure") {
      x_pos  <- x_range[2] - x_span * 0.02   # right edge
      y_pos  <- y_range[1] + y_span * 0.02   # bottom edge
      h_just <- 1
      v_just <- 0
    } else {
      x_pos  <- x_range[1] + x_span * 0.02   # left edge
      y_pos  <- y_range[2] - y_span * 0.02   # top edge
      h_just <- 0
      v_just <- 1
    }
    
    annot_b_list[[idx]] <- data.frame(
      Domain       = dom,
      SpatialLabel = sp_lbl,
      x_pos  = x_pos,
      y_pos  = y_pos,
      hjust  = h_just,
      vjust  = v_just,
      lbl = paste0(
        sp_lbl, "\n",
        "OLS: \u03B2=", sprintf("%.2f", beta_ols), star(p_ols),
        "  R\u00B2=", sprintf("%.3f", r2_ols), "\n",
        "GAM: edf=", sprintf("%.1f", edf_gam), star(p_gam),
        "  R\u00B2=", sprintf("%.3f", r2_gam)
      ),
      stringsAsFactors = FALSE
    )
    idx <- idx + 1
  }
}

annot_b_df <- bind_rows(annot_b_list) %>%
  mutate(
    Domain       = factor(Domain, levels = c("Grocery", "Electronics")),
    SpatialLabel = factor(SpatialLabel, levels = c("Green Exposure", "Desakota"))
  )

# ── Build Panel 4b — 1 row × 2 column (Grocery | Electronics) ─────────────────

make_panel_b <- function(domain_name, title_label) {
  
  d_dom    <- df_plot_b  %>% filter(Domain == domain_name)
  a_dom    <- annot_b_df %>% filter(Domain == domain_name)
  
  ggplot(d_dom,
         aes(x = Spatial_Value, y = Actual_Market_Behavior,
             colour = SpatialLabel)) +
    
    # Scatter — small, semi-transparent
    geom_point(alpha = 0.40, size = 1.4, stroke = 0) +
    
    # OLS fit — thin dotted
    geom_smooth(aes(colour = SpatialLabel),
                method    = "lm",
                formula   = y ~ x,
                linetype  = "dotted",
                linewidth = 0.85,
                se        = TRUE,
                alpha     = 0.10) +
    
    # GAM fit — thick solid
    geom_smooth(aes(colour = SpatialLabel),
                method    = "gam",
                formula   = y ~ s(x, bs = "tp"),
                linetype  = "solid",
                linewidth = 1.35,
                se        = TRUE,
                alpha     = 0.10) +
    
    # Annotation box — position and justification differ per index
    geom_label(data    = a_dom,
               aes(x = x_pos, y = y_pos, label = lbl,
                   colour = SpatialLabel,
                   hjust  = hjust,
                   vjust  = vjust),
               inherit.aes = FALSE,
               show.legend = FALSE,        # revise for legend
               size = 2.1,
               lineheight = 1.1, family = "sans",
               fill = "white", alpha = 0.88,
               label.size = 0.25,
               label.padding = unit(0.20, "lines")) +
    
    scale_colour_manual(
      values = c("Green Exposure" = col_green, "Desakota" = col_desakota),
      name   = "Spatial Index"
    ) +
    guides(
      colour = guide_legend(
        title          = "Spatial Index",
        override.aes   = list(
          linetype  = c("solid", "solid"),   # show a line swatch
          linewidth = c(1.0, 1.0),
          shape     = c(16, 16),
          fill      = NA                     # suppress the label-fill square
        )
      )
    )+
    
    labs(title = paste0("b.", domain_name),
         x = "Spatial Index (Z-Score)",
         y = "Observed Market Behavior (Z-Score)") +
    
    theme_fig4() +
    theme(
      axis.title.x    = element_text(size = 6.5, face = "plain",
                                     margin = ggplot2::margin(t = 4)),
      axis.title.y    = element_text(size = 6.5, face = "plain", angle = 90,
                                     margin = ggplot2::margin(r = 4)),
      legend.position = "bottom",
      legend.margin   = ggplot2::margin(2, 0, 0, 0)
    )
}

panel4b_grocery     <- make_panel_b("Grocery",     "b")
panel4b_electronics <- make_panel_b("Electronics", "b")


# ══════════════════════════════════════════════════════════════════════════════
# ASSEMBLE FIGURE 4
# ══════════════════════════════════════════════════════════════════════════════

fig4 <- (panel4a) /
  (panel4b_grocery | panel4b_electronics) +
  plot_layout(heights = c(1.8, 1)) +
  plot_annotation(
    theme = theme(
      plot.background = element_rect(fill = "white", colour = NA)
    )
  )


# ══════════════════════════════════════════════════════════════════════════════
# SAVE
# ══════════════════════════════════════════════════════════════════════════════

out_dir <- "figures"
dir.create(file.path(out_dir, "png"), showWarnings = FALSE, recursive = TRUE)

ggsave(file.path(out_dir, "Figure4_FE.png"),
       fig4, width = 220, height = 200, units = "mm", dpi = 300)

if (requireNamespace("svglite", quietly = TRUE)) {
  dir.create(file.path(out_dir, "svg"), showWarnings = FALSE, recursive = TRUE)
  ggsave(file.path(out_dir, "Figure4_FE.svg"),
         fig4, width = 220, height = 200, units = "mm",
         device = svglite::svglite, bg = "white")
}


