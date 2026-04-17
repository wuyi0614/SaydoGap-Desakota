################################################################################
# Supp. Figure 4: Spatial Greening Metrics & Nature Connectedness (CTN)
#
# What it does:
#   Regresses CTN on multiple spatial greening indices (with optional controls)
#   and produces a composite figure with:
#     Panel a: Standardised coefficient plot (effect sizes)
#     Panel b: Max change in adjusted R-squared per category
#     Panels c1-c4: Scatter plots with marginal density for selected indices
#
# Input:  data/IncludingLogData.csv
# Output: figures/SFig4_Spatial_vs_NC{_controlled|_bivariate}.png
#
# Dependency: Run STable18_tranformation.R first (generates input CSV).
################################################################################
rm(list=ls())
df <- read.csv("data/IncludingLogData.csv") %>%
  mutate(country=Country,
         isIslam = case_when(
          Main.religion == "Islam" ~ 1,
           TRUE ~ 0),
         isChristian = case_when(
           Main.religion == "Christianity" ~ 1,
           TRUE ~ 0))
  
# ── Libraries ─────────────────────────────────────────────────────────────────
library(dplyr)
library(tidyr)
library(broom)
library(ggplot2)
library(patchwork)
library(ggExtra)
library(scales)
library(ggside)
# ══════════════════════════════════════════════════════════════════════════════
# USER TOGGLE: Set to TRUE to include controls, FALSE for bivariate models
# ══════════════════════════════════════════════════════════════════════════════
INCLUDE_CONTROLS <- TRUE
scatter_var <- c("Blue.Exposure.Index", "Green.Exposure.Index", "Desakota_Index_CropOnly_log", "Desakota_Index_CropAndGreen_log")
# ══════════════════════════════════════════════════════════════════════════════

# ── 1. Variable metadata ─────────────────────────────────────────────────────

var_meta <- tribble(
  ~variable,                              ~label,                       ~category,             ~is_log,
  "Coastal.Accessibility_log",            "Coastal Accessibility",      "Proximity",           TRUE,
  "Green.Space.Accessibility_within_300m","Green Space Access (300 m)", "Proximity",           FALSE,
  "Green.Space.Accessibility_within_500m","Green Space Access (500 m)", "Proximity",           FALSE,
  "Patch.Density_log",                    "Patch Density",              "Landscape Structure", TRUE,
  "Largest.Patch.Index_log",              "Largest Patch Index",        "Landscape Structure", TRUE,
  "Patch.Dispersion.Index",               "Patch Dispersion Index",     "Landscape Structure", FALSE,
  "Per.Capita.Green.Space_log",           "Per Capita Green Space",     "Population Averaged", TRUE,
  "Green.Space.Proportion_log",           "Green Space Proportion",     "Area Averaged",       TRUE,
  "Blue.Exposure.Index",                  "Blue Exposure Index",        "Population Weighted", FALSE,
  "Green.Exposure.Index",                 "Green Exposure Index",       "Population Weighted", FALSE,
  "Desakota_Index_CropAndGreen_log",      "Desakota (Crop & Green)",    "Desakota",            TRUE,
  "Desakota_Index_CropOnly_log",          "Desakota (Crop Only)",       "Desakota",            TRUE,
  "crop_Land",                            "Cropland Index",             "Desakota",            FALSE
)

var_meta <- var_meta %>%
  mutate(display_label = ifelse(is_log, paste0(label, "\u2020"), label))

# ── 2. Color palette ─────────────────────────────────────────────────────────
cat_colors <- c(
  "Proximity"           = "#4D7CA3", # Slate Blue 
  "Landscape Structure" = "#8D8D8D", # Medium Grey 
  "Population Averaged" = "#A37C9B", # Dusty Mauve/Purple 
  "Area Averaged"       = "#6A9F76", # Sage Green 
  "Population Weighted" = "#E6A01D", # Mustard/Dark Gold 
  "Desakota"            = "#B35806"  # Deep Terracotta
)

cat_order <- c("Proximity", "Landscape Structure", "Population Averaged",
               "Area Averaged", "Population Weighted", "Desakota")

# ── 3. Control variables & Standardization ───────────────────────────────────
control_vars_all <- c("GDP_per", "onlineShoppingExperience", "isHighEdu",'socialMediaHrs','isIslam','isChristian')

# Resolve active controls based on toggle
ctrl <- if (INCLUDE_CONTROLS) control_vars_all else character(0)

iv_cols    <- var_meta$variable
cols_to_z  <- unique(c(iv_cols, ctrl))

df_z <- df
df_z[cols_to_z] <- lapply(df_z[cols_to_z], function(x) as.numeric(scale(x)))

# Helper: build predictor vector (focal vars + controls if active)
add_ctrl <- function(focal) c(focal, ctrl)

# Dynamic label fragments
ctrl_label <- if (INCLUDE_CONTROLS) ", controlling for covariates" else ""
ctrl_r2    <- if (INCLUDE_CONTROLS) " (over baseline covariates)"  else ""

# ── 4. Panel a — Standardised effect sizes ───────────────────────────────────

panel_a_data <- var_meta %>%
  rowwise() %>%
  mutate(
    fmla   = list(reformulate(add_ctrl(variable), "genGreenConnectness")),
    model  = list(lm(fmla, data = df_z)),
    tidied = list(tidy(model, conf.int = TRUE))
  ) %>%
  ungroup() %>%
  unnest(tidied) %>%
  filter(term == variable) %>%
  dplyr::select(variable, display_label, category, estimate, conf.low, conf.high, p.value) %>%
  mutate(
    sig = case_when(
      p.value < 0.01 ~ "***",
      p.value < 0.05  ~ "**",
      p.value < 0.1  ~ "*",
      TRUE            ~ ""
    ),
    display_label_sig = paste0(display_label, "  ", sig)
  ) %>%
  mutate(category = factor(category, levels = rev(cat_order))) %>%
  arrange(category, estimate) %>%
  mutate(display_label_sig = factor(display_label_sig, levels = display_label_sig))

p_a <- ggplot(panel_a_data,
              aes(x = estimate, y = display_label_sig,
                  xmin = conf.low, xmax = conf.high,
                  color = category)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50",
             linewidth = 0.4) +
  geom_pointrange(size = 0.45, linewidth = 0.6, fatten = 3) +
  scale_color_manual(values = cat_colors, name = "Category") +
  labs(
    x = bquote("Standardised Effect Size (" * beta * ")" * .(ctrl_label)),
    y = NULL,
    tag = "a"
  ) +
  theme_classic(base_size = 11, base_family = "sans") +
  theme(
    legend.position      = "bottom",
    legend.title         = element_text(face = "bold", size = 9),
    legend.text          = element_text(size = 8),
    legend.key.size      = unit(0.35, "cm"),
    axis.line.y          = element_blank(),
    axis.ticks.y         = element_blank(),
    panel.grid.major.x   = element_line(colour = "grey90", linetype = "dashed",
                                        linewidth = 0.3),
    panel.grid.major.y   = element_blank(),
    plot.tag             = element_text(face = "bold", size = 14, family = "sans"),
    plot.tag.position    = c(0, 1),
    plot.margin          = ggplot2::margin(5, 10, 5, 5)
  ) +
  guides(color = guide_legend(nrow = 1, override.aes = list(size = 0.8)))

# ── 5. Panel B — Max TRUE Delta Adjusted R² per category ─────────────────

panel_b_data <- var_meta %>%
  rowwise() %>%
  mutate(
    fmla_full   = list(reformulate(add_ctrl(variable), "genGreenConnectness")),
    mod_full    = list(lm(fmla_full, data = df_z)),
    adj_r2_full = summary(mod_full)$adj.r.squared,
    
    # Matched baseline using the exact rows that survived listwise deletion
    fmla_base   = list(reformulate(if(length(ctrl)>0) ctrl else "1", "genGreenConnectness")),
    mod_base    = list(lm(fmla_base, data = mod_full$model)),
    adj_r2_base = summary(mod_base)$adj.r.squared,
    
    true_delta_r2 = adj_r2_full - adj_r2_base
  ) %>%
  ungroup() %>%
  group_by(category) %>%
  slice_max(order_by = true_delta_r2, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  dplyr::select(category, true_delta_r2, best_var = variable) %>%
  mutate(category = factor(category, levels = rev(cat_order)))

p_b <- ggplot(panel_b_data, aes(x = true_delta_r2, y = category, fill = category)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = sprintf("%.3f", true_delta_r2)),
            hjust = -0.15, size = 3, family = "sans") +
  scale_fill_manual(values = cat_colors) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.35)),
                     labels = label_number(accuracy = 0.001)) +
  labs(
    x = bquote("\u0394 Adjusted " * italic(R)^2 * .(ctrl_r2)),
    y = NULL,
    tag = "b"
  ) +
  theme_classic(base_size = 11, base_family = "sans") +
  theme(
    legend.position    = "none",
    axis.line.y        = element_blank(),
    axis.ticks.y       = element_blank(),
    panel.grid         = element_blank(),
    plot.tag           = element_text(face = "bold", size = 14, family = "sans"),
    plot.tag.position  = c(0, 1),
    plot.margin        = ggplot2::margin(5, 10, 5, 5)
  )

# ── 6. Panel C — Scatterplots with β + p annotation ─────────────────────────

format_p <- function(p) {
  if (p < 0.001) return("p < 0.001")
  return(paste0("p = ", formatC(p, format = "f", digits = 3)))
}


make_scatter <- function(xvar, xlab_full, pt_color, panel_tag, y_title = NULL) {
  
  fmla_full   <- reformulate(add_ctrl(xvar), "genGreenConnectness")
  mod_full    <- lm(fmla_full, data = df_z)
  tidy_mod    <- tidy(mod_full, conf.int = TRUE) %>% filter(term == xvar)
  
  beta_val    <- tidy_mod$estimate
  p_val       <- tidy_mod$p.value
  full_r2     <- summary(mod_full)$adj.r.squared
  
  fmla_base   <- reformulate(if(length(ctrl)>0) ctrl else "1", "genGreenConnectness")
  mod_base    <- lm(fmla_base, data = mod_full$model)
  base_r2     <- summary(mod_base)$adj.r.squared
  delta_r2    <- full_r2 - base_r2
  
  sig_star <- ifelse(p_val < 0.01, "***",
                     ifelse(p_val < 0.05, "**",
                            ifelse(p_val < 0.1, "*", "")))
  
  annot <- paste0(
    "\u03B2 = ", formatC(beta_val, format = "f", digits = 3), sig_star,
    "\n", format_p(p_val),
    "\n\u0394 Adj. R\u00B2 = ", formatC(delta_r2, format = "f", digits = 3)
  )
  
  x_range <- range(df_z[[xvar]], na.rm = TRUE)
  y_range <- range(df_z$genGreenConnectness, na.rm = TRUE)
  
  p <- ggplot(df_z, aes(x = .data[[xvar]], y = genGreenConnectness)) +
    geom_point(color = pt_color, alpha = 0.55, size = 1.6) +
    geom_smooth(method = "lm", se = TRUE, color = "black",
                linewidth = 0.7, fill = "grey80", alpha = 0.3) +
    
    # Native Marginal Density Plots via ggside
    geom_xsidedensity(fill = pt_color, alpha = 0.3, color = pt_color, linewidth = 0.5) +
    geom_ysidedensity(fill = pt_color, alpha = 0.3, color = pt_color, linewidth = 0.5) +
    
    annotate("text",
             x = x_range[1] + diff(x_range) * 0.03,
             y = y_range[2] - diff(y_range) * 0.03,
             label = annot,
             hjust = 0, vjust = 1, size = 3.2, family = "sans",
             color = "grey20", lineheight = 1.1) +
    annotate("text",
             x = x_range[1] - diff(x_range) * 0.06,
             y = y_range[2] + diff(y_range) * 0.10,
             label = panel_tag, fontface = "bold", size = 5,
             family = "sans", hjust = 0, vjust = 1) +
    labs(x = xlab_full, y = y_title) +
    coord_cartesian(clip = "off") +
    theme_classic(base_size = 10, base_family = "sans") +
    theme(
      plot.margin = ggplot2::margin(t = 15, r = 8, b = 5, l = 5),
      ggside.panel.scale.x = 0.25,
      ggside.panel.scale.y = 0.25,
      ggside.axis.text = element_blank(),
      ggside.axis.ticks = element_blank(),
      ggside.axis.line = element_blank(),
      ggside.panel.background = element_blank()
    )
  
  return(p)
}

# Create the 4 plots
# Create a named list to store the plots
plots <- list()

# Generate all four plots automatically
for(i in seq_along(scatter_var)) {
  var <- scatter_var[i]
  var_info <- var_meta %>% filter(variable == var)
  
  # Create label with dagger if variable is logged
  label <- if(var_info$is_log) {
    paste0("Standardised ", var_info$label, "\u2020")
  } else {
    paste0("Standardised ", var_info$label)
  }
  
  # Set y_title only for the first plot (C1)
  y_title <- if(i == 1) "Nature Connectedness (CTN)" else NULL
  
  # Create plot name (p_c1, p_c2, etc.)
  plot_name <- paste0("p_c", i)
  
  # Assign the plot to the list
  plots[[plot_name]] <- make_scatter(
    var,
    label,
    cat_colors[var_info$category],
    paste0("c", i),
    y_title = y_title
  )
}

# ── 7. Assemble with patchwork ───────────────────────────────────────────────

top_row    <- wrap_elements((p_a + p_b) + plot_layout(widths = c(2, 1)))
bottom_row <- wrap_elements(plots$p_c1 | plots$p_c2 | plots$p_c3 | plots$p_c4)


# Dynamic footnote
caption_text <- paste0(
  "Note: \u2020 log-transformed variable.  ",
  "*** p < 0.01, ** p < 0.05, * p < 0.1."
)
if (INCLUDE_CONTROLS) {
  caption_text <- paste0(
    caption_text,
    "  All models control for GDP per capita, online shopping experience, ",
    "and education level (standardised)."
  )
}

composite <- (top_row / bottom_row) +
  plot_layout(heights = c(1.2, 1)) +
  plot_annotation(
    caption = caption_text,
    theme = theme(
      plot.caption = element_text(
        size = 8, hjust = 0, family = "sans",
        color = "grey40", margin = ggplot2::margin(t = 10)
      )
    )
  )

# ── 8. Save ──────────────────────────────────────────────────────────────────
suffix <- if (INCLUDE_CONTROLS) "_controlled" else "_bivariate"

# Use width 14 or 15 instead of 12 so the 3 bottom panels have enough breathing room
ggsave(paste0("figures/SFig4_Spatial_vs_NC", suffix, ".png"), composite,
       width = 14, height = 10, units = "in", dpi = 600)

