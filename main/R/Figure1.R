################################################################################
# Figure 1: Green Illusion — Cascade & Geographic Distribution
#
# What it does:
#   Produces a composite figure showing the green illusion effect across
#   Southeast Asian cities, combining behavioral cascade plots with a map.
#
# Layout:
#   Panel A (top row): Four cascade sub-plots (BPN/LPM x Grocery/Electronic)
#     showing Intention → Reported → Observed attrition per city/country.
#   Panel B (bottom):  Geographic map with dual encoding
#     (size = BPN Reporting Bias, color = LPM Reporting Bias).
#
# Input:  data/MergedPanelV5.csv, data/GeoIndexV6.xlsx
# Output: figures/Figure1_GreenIllusion.png, figures/Figure1_GreenIllusion.svg
################################################################################
rm(list = ls())
library(dplyr)
library(tidyverse)
library(patchwork)
library(ggrepel)
library(scales)
library(rnaturalearth)
library(rnaturalearthdata)
library(sf)
if (requireNamespace("spdep", quietly = TRUE)) library(spdep)
library(svglite)
df <- read.csv("data/MergedPanelV5.csv") %>%
  mutate(country=Country)

# ── Output directory ─────────────────────────────────────────────────────────
out_dir <- "figures"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

################################################################################
# 1. GRAPH THEME
################################################################################

theme_pub <- function(base_size = 7) {
  theme_minimal(base_size = base_size, base_family = "Arial") %+replace%
    theme(
      # Titles
      plot.title       = element_text(size = 8, face = "bold", hjust = 0,
                                      margin = ggplot2::margin(b = 2)),
      plot.subtitle    = element_text(size = 6.5, color = "grey35", hjust = 0,
                                      margin = ggplot2::margin(b = 3)),
      # Axes
      axis.title       = element_text(size = 7, face = "plain"),
      axis.title.x     = element_blank(),
      axis.text        = element_text(size = 6, color = "grey20"),
      axis.text.x      = element_text(margin = ggplot2::margin(t = 1)),
      axis.ticks       = element_line(linewidth = 0.3, color = "grey50"),
      axis.ticks.length = unit(1.5, "pt"),
      axis.line        = element_line(linewidth = 0.35, color = "grey30"),
      # Grid
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      # Legend
      legend.title     = element_text(size = 6.5, face = "bold"),
      legend.text      = element_text(size = 6),
      legend.key.size  = unit(0.3, "cm"),
      legend.margin    = ggplot2::margin(0, 0, 0, 0),
      legend.position  = "bottom",
      # Strips (removed — we don't use facets here)
      strip.text       = element_blank(),
      strip.background = element_blank(),
      # Plot margins
      plot.margin      = ggplot2::margin(4, 4, 4, 4)
    )
}

# Country color-blind-safe palette (Okabe-Ito extended)
country_colors <- c(
  "Philippines" = "#D55E00",
  "Indonesia"   = "#0072B2",
  "Thailand"    = "#009E73",
  "Vietnam"     = "#CC79A7",
  "Malaysia"    = "#E69F00",
  "Singapore"   = "#56B4E9",
  "SEA Region"     = "black"
)

################################################################################
# 2. DATA PROCESSING  
################################################################################

# ── 2a. Process landscape data  ────────────────
process_domain_data <- function(data, domain_name) {
  suffix <- domain_name
  var_likert_bpn <- paste0("stdGreen", suffix, "Likert_BPN")
  var_report_bpn <- paste0("reportMonthlyGreen", suffix, "_BPN")
  var_observed_bpn <- paste0("greenSpendingShare", suffix, "_BPN")
  var_likert_lpm <- paste0("stdGreen", suffix, "Likert_LPM")
  var_report_lpm <- paste0("reportMonthlyGreen", suffix, "_LPM")
  var_observed_lpm <- paste0("greenSpendingShare", suffix, "_LPM")

  df_bpn <- data %>%
    dplyr::select(city, country,
           all_of(c(var_likert_bpn, var_report_bpn, var_observed_bpn))) %>%
    rename(Stage1_Intention = !!sym(var_likert_bpn),
           Stage2_Reported  = !!sym(var_report_bpn),
           Stage3_Observed    = !!sym(var_observed_bpn)) %>%
    filter(complete.cases(.)) %>%
    mutate(Domain = domain_name, Framework = "BPN",
           Gap1_SaySay = Stage1_Intention - Stage2_Reported,
           Gap2_SayDo  = Stage2_Reported  - Stage3_Observed)

  df_lpm <- data %>%
    dplyr::select(city, country,
           all_of(c(var_likert_lpm, var_report_lpm, var_observed_lpm))) %>%
    rename(Stage1_Intention = !!sym(var_likert_lpm),
           Stage2_Reported  = !!sym(var_report_lpm),
           Stage3_Observed    = !!sym(var_observed_lpm)) %>%
    filter(complete.cases(.)) %>%
    mutate(Domain = domain_name, Framework = "LPM",
           Gap1_SaySay = Stage1_Intention - Stage2_Reported,
           Gap2_SayDo  = Stage2_Reported  - Stage3_Observed)

  bind_rows(df_bpn, df_lpm)
}

df_grocery    <- process_domain_data(df, "Grocery")
df_electronic <- process_domain_data(df, "Electronic")
df_landscape  <- bind_rows(df_grocery, df_electronic)

# Long format for cascade
df_cascade_long <- df_landscape %>%
  dplyr::select(city, country, Domain, Framework, starts_with("Stage")) %>%
  pivot_longer(cols = starts_with("Stage"),
               names_to = "Stage_Raw", values_to = "Score") %>%
  mutate(
    Stage_Label = factor(case_when(
      Stage_Raw == "Stage1_Intention" ~ "Intention",
      Stage_Raw == "Stage2_Reported"  ~ "Reported",
      Stage_Raw == "Stage3_Observed"    ~ "Observed"
    ), levels = c("Intention", "Reported", "Observed"))
  )

# Means
df_global_mean <- df_cascade_long %>%
  group_by(Domain, Framework, Stage_Label) %>%
  summarise(Score = mean(Score, na.rm = TRUE), .groups = "drop")

df_country_mean <- df_cascade_long %>%
  group_by(Domain, Framework, country, Stage_Label) %>%
  summarise(Score = mean(Score, na.rm = TRUE), .groups = "drop")

comparison_metrics <- df_landscape %>%
  group_by(Domain, Framework) %>%
  summarise(
    Intention = mean(Stage1_Intention, na.rm = TRUE),
    Reported  = mean(Stage2_Reported, na.rm = TRUE),
    Observed    = mean(Stage3_Observed, na.rm = TRUE),
    Gap1 = mean(Gap1_SaySay, na.rm = TRUE),
    Gap2 = mean(Gap2_SayDo, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(Total_Attrition_Pct = (1 - Observed / Intention) * 100)

# ── 2b. Build geo landscape data (from Geo_Distribution.R) ──────────────────
build_landscape_wide <- function(data, domain) {
  likert_bpn <- paste0("stdGreen", domain, "Likert_BPN")
  report_bpn <- paste0("reportMonthlyGreen", domain, "_BPN")
  observed_bpn <- paste0("greenSpendingShare", domain, "_BPN")
  likert_lpm <- paste0("stdGreen", domain, "Likert_LPM")
  report_lpm <- paste0("reportMonthlyGreen", domain, "_LPM")
  observed_lpm <- paste0("greenSpendingShare", domain, "_LPM")

  data %>%
    filter(!is.na(.data[[likert_bpn]]) &
             !is.na(.data[[report_bpn]]) &
             !is.na(.data[[observed_bpn]])) %>%
    mutate(
      Stage1_Intention_BPN = .data[[likert_bpn]],
      Stage2_Reported_BPN  = .data[[report_bpn]],
      Stage3_Observed_BPN    = .data[[observed_bpn]],
      Gap1_SaySay_BPN      = Stage1_Intention_BPN - Stage2_Reported_BPN,
      Gap2_SayDo_BPN       = Stage2_Reported_BPN  - Stage3_Observed_BPN,
      Gap_Total_BPN        = Stage1_Intention_BPN - Stage3_Observed_BPN,
      Stage1_Intention_LPM = .data[[likert_lpm]],
      Stage2_Reported_LPM  = .data[[report_lpm]],
      Stage3_Observed_LPM    = .data[[observed_lpm]],
      Gap1_SaySay_LPM      = Stage1_Intention_LPM - Stage2_Reported_LPM,
      Gap2_SayDo_LPM       = Stage2_Reported_LPM  - Stage3_Observed_LPM,
      Gap_Total_LPM        = Stage1_Intention_LPM - Stage3_Observed_LPM
    )
}

df_landscape_grocery    <- build_landscape_wide(df, "Grocery")
df_landscape_electronic <- build_landscape_wide(df, "Electronic")

# ── 2c. Merge coordinates (adjust path to your coordinate file) ─────────────
coords_matched <- readxl::read_excel("data/GeoIndexV6.xlsx") %>%
  mutate(country = Country, latitude = Latitude, longitude = Longitude) %>%
  dplyr::select(city, country, latitude, longitude)

df_landscape_grocery <- df_landscape_grocery %>%
  left_join(coords_matched, by = c("city", "country"))
df_landscape_electronic <- df_landscape_electronic %>%
  left_join(coords_matched, by = c("city", "country"))


################################################################################
# 3. PANEL A — FOUR CASCADE SUB-PLOTS sharing one Y axis
#    A1: BPN × Grocery    A2: BPN × Electronic
#    A3: LPM × Grocery    A4: LPM × Electronic
################################################################################

# Factory function: one cascade sub-plot per Framework × Domain combination
make_cascade_subplot <- function(fw, dom, panel_label,
                                  color_line, color_point,
                                  show_y_title = TRUE) {

  d_lines   <- df_cascade_long   %>% filter(Framework == fw, Domain == dom)
  d_global  <- df_global_mean    %>% filter(Framework == fw, Domain == dom)
  d_country <- df_country_mean   %>% filter(Framework == fw, Domain == dom)
  d_metrics <- comparison_metrics %>% filter(Framework == fw, Domain == dom)
  
  # Add a label column so the regional average can appear in the legend
  d_global <- d_global %>% mutate(Legend = "SEA Region")

  p <- ggplot() +
    # City trajectories (faint)
    geom_line(data = d_lines,
              aes(x = Stage_Label, y = Score, group = city),
              color = color_line, alpha = 0.06, linewidth = 0.15) +
    # Country trajectories
    geom_line(data = d_country,
              aes(x = Stage_Label, y = Score, group = country, color = country),
              linewidth = 0.45, alpha = 0.55) +
    # Regional average
    geom_line(data = d_global,
              aes(x = Stage_Label, y = Score, group = 1),
              color = color_point, linewidth = 0.9) +
    geom_point(data = d_global,
               aes(x = Stage_Label, y = Score),
               color = color_point, size = 1.8, shape = 21,
               fill = "white", stroke = 1.1) +
    # Value labels
    geom_text(data = d_global,
              aes(x = Stage_Label, y = Score,
                  label = sprintf("%.3f", Score)),
              vjust = -1.3, fontface = "bold",
              color = color_point, size = 3) +
    # Gap annotations
    annotate("text", x = 1.5, y = 0.96,
             label = sprintf("Reported Gap: %.2f", d_metrics$Gap1),
             size = 2.5, color = "#D95F02", fontface = "bold") +
    annotate("text", x = 2.5, y = 0.88,
             label = sprintf("Reporting Bias: %.2f", d_metrics$Gap2),
             size = 2.5, color = "#B22222", fontface = "bold") +
    # Scales — includes all 7 entries (6 countries + SEA Region)
    scale_color_manual(values = country_colors, name = NULL) +
    scale_y_continuous(limits = c(0, 1.05), breaks = seq(0, 1, 0.2),
                       labels = scales::percent_format(accuracy = 1)) +
    labs(
      title    = sprintf("%s  %s — %s", panel_label, fw, dom),
      y        = if (show_y_title) "Score" else NULL
    ) +
    theme_pub() +
    theme(
      legend.position = "none",
      axis.text.x     = element_text(size = 5.5, margin = ggplot2::margin(t = 2)),
      plot.margin      = ggplot2::margin(4, 2, 4, 2)
    )

  # Remove y-axis text for non-leftmost panels to save space

  if (!show_y_title) {
    p <- p + theme(axis.title.y = element_blank(),
                   axis.text.y  = element_blank(),
                   axis.ticks.y = element_blank())
  }

  p
}

# Build the four sub-plots — now A1–A4 sharing one Y axis
p_a1 <- make_cascade_subplot("BPN", "Grocery",    "a1.", "black", "black",
                              show_y_title = TRUE)
p_a2 <- make_cascade_subplot("BPN", "Electronic", "a2.", "black", "black",
                              show_y_title = FALSE)
p_a3 <- make_cascade_subplot("LPM", "Grocery",    "a3.", "black", "black",
                              show_y_title = FALSE)
p_a4 <- make_cascade_subplot("LPM", "Electronic", "a4.", "black", "black",
                              show_y_title = FALSE)

# ── A4 with shared legend on the right ────────────────────────────────────────
d_global_a4  <- df_global_mean  %>%
  filter(Framework == "LPM", Domain == "Electronic") %>%
  mutate(Legend = "SEA Region")
d_country_a4 <- df_country_mean %>%
  filter(Framework == "LPM", Domain == "Electronic")

p_a4 <- make_cascade_subplot("LPM", "Electronic", "a4.", "black", "black",
                             show_y_title = FALSE) +
  # Re-add country lines (already present, but needed for legend rebuild)
  geom_line(data = d_country_a4,
            aes(x = Stage_Label, y = Score, group = country, color = country),
            linewidth = 0.45, alpha = 0.55) +
  # Re-add regional line mapped to color
  geom_line(data = d_global_a4,
            aes(x = Stage_Label, y = Score, group = 1, color = Legend),
            linewidth = 0.9) +
  scale_color_manual(values = country_colors, name = NULL) +
  guides(color = guide_legend(ncol = 1,
                              override.aes = list(linewidth = 0.8, alpha = 1))) +
  theme(
    legend.position   = "right",
    legend.key.width  = unit(0.4, "cm"),
    legend.key.height = unit(0.25, "cm"),
    legend.text       = element_text(size = 5.5),
    legend.margin     = ggplot2::margin(0, 0, 0, 2),
    plot.margin       = ggplot2::margin(4, 2, 4, 2)
  )

# Assemble top row: four plots side by side, shared Y axis (only A1 shows it)
top_row <- (p_a1 | p_a2 | p_a3 | p_a4) +
  plot_layout(widths = c(1.12, 1, 1, 1.25))   # A4 wider to accommodate legend

print(top_row)
################################################################################
# 4. PANEL B — GEOGRAPHIC MAP  
################################################################################

build_panel_C <- function(df_landscape_domain, domain_label = "Grocery") {

  df_geo <- df_landscape_domain %>%
    filter(!is.na(latitude) & !is.na(longitude))

  # Spatial stats
  has_spdep <- requireNamespace("spdep", quietly = TRUE)
  if (has_spdep) {
    df_geo_sf   <- st_as_sf(df_geo, coords = c("longitude", "latitude"), crs = 4326)
    coords_mat  <- st_coordinates(df_geo_sf)
    knn_weights <- spdep::knearneigh(coords_mat, k = min(5, nrow(df_geo) - 1))
    nb          <- spdep::knn2nb(knn_weights)
    weights     <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
    moran_BPN   <- spdep::moran.test(df_geo$Gap2_SayDo_BPN, weights,
                                      zero.policy = TRUE)
    moran_LPM   <- spdep::moran.test(df_geo$Gap2_SayDo_LPM, weights,
                                      zero.policy = TRUE)
  } else {
    moran_BPN <- moran_LPM <- list(estimate = c(I = NA), p.value = NA)
  }

  sig_stars <- function(p) {
    if (is.na(p)) return("")
    if (p < 0.001) return("***")
    if (p < 0.01)  return("**")
    if (p < 0.05)  return("*")
    ""
  }
  
  aspect_ratio <- 2

  # Base map
  world       <- ne_countries(scale = "medium", returnclass = "sf")
  sea_countries <- c("Indonesia", "Malaysia", "Philippines",
                     "Singapore", "Thailand", "Vietnam")
  sea_map     <- world %>% filter(name %in% sea_countries |
                                    admin %in% sea_countries)

  lon_range <- range(df_geo$longitude, na.rm = TRUE)
  lat_range <- range(df_geo$latitude,  na.rm = TRUE)
  lon_pad   <- diff(lon_range) * 0.05
  lat_pad   <- diff(lat_range) * 0.05

  # Cities to label
  extreme_bpn <- df_geo %>% arrange(desc(abs(Gap2_SayDo_BPN))) %>% slice(1:3)
  extreme_lpm <- df_geo %>% filter(!is.na(Gap2_SayDo_LPM)) %>%
    arrange(desc(abs(Gap2_SayDo_LPM))) %>% slice(1:3)
  capitals    <- df_geo %>% filter(!is.na(isCapitalCity) & isCapitalCity == 1)
  cities_to_label <- capitals %>%
    distinct(city, country, .keep_all = TRUE)

  map_color_palette <- c("#006837", "#1a9850", "#66bd63",
                         "#fee08b", "#f46d43", "#d73027", "#a50026")

  panel_C <- ggplot() +
    geom_rect(aes(xmin = lon_range[1] - lon_pad, xmax = lon_range[2] + lon_pad,
                  ymin = lat_range[1] - lat_pad, ymax = lat_range[2] + lat_pad),
              fill = "#D6EAF8", alpha = 0.3) +
    geom_sf(data = sea_map, fill = "#F5F5DC", color = "grey60", linewidth = 0.3) +
    # Points with dual encoding: size = BPN Gap2, color = LPM Gap2
    geom_point(data = df_geo %>% filter(!is.na(Gap2_SayDo_LPM)),
               aes(x = longitude, y = latitude,
                   color = Gap2_SayDo_LPM, size = Gap2_SayDo_BPN),
               alpha = 0.8, shape = 16) +
    # Grey points for missing LPM
    geom_point(data = df_geo %>% filter(is.na(Gap2_SayDo_LPM)),
               aes(x = longitude, y = latitude, size = Gap2_SayDo_BPN),
               color = "grey50", alpha = 0.6, shape = 16) +
    # Add text annotations for Moran's I
    annotate("text", x = 98, y = -6,
             label = sprintf("BPN Moran's I = %.3f%s", moran_BPN$estimate[1], sig_stars(moran_BPN$p.value)),
             size = 2.5, color = "#B22222", fontface = "bold") +
    annotate("text", x = 98, y = -8,
             label = sprintf("LPM Moran's I = %.3f%s", moran_LPM$estimate[1], sig_stars(moran_LPM$p.value)),
             size = 2.5, color = "#B22222", fontface = "bold") +
    scale_color_gradientn(
      colors = map_color_palette,
      values = rescale(c(0, 0.15, 0.3, 0.45, 0.6, 0.85)),
      limits = c(-0.1, 0.85), na.value = "grey50",
      name   = "Reporting Bias\n(LPM)",
      breaks = seq(0, 0.8, 0.2),
      guide  = guide_colorbar(
        title.position = "top", title.hjust = 0.5,
        barwidth = 1.2, barheight = 8,
        frame.colour = "grey30", ticks.colour = "grey30",
        ticks.linewidth = 0.6, order = 1)
    ) +
    scale_size_continuous(
      range  = c(1.5, 7), limits = c(-0.1, 1),
      name   = "Reporting Bias\n(BPN)",
      breaks = c(0, 0.25, 0.5, 0.75, 1.0),
      guide  = guide_legend(
        title.position = "top", title.hjust = 0.5,
        override.aes = list(color = "grey30", alpha = 0.8), order = 2)
    ) +
    geom_text_repel(data = cities_to_label,
                    aes(x = longitude, y = latitude, label = city),
                    size = 2.2, fontface = "bold",
                    box.padding = 0.5, point.padding = 0.3,
                    max.overlaps = 25, min.segment.length = 0.1,
                    segment.size = 0.25, segment.color = "grey30",
                    force = 2, force_pull = 1) +
    coord_sf(xlim   = c(lon_range[1] - lon_pad, lon_range[2] + lon_pad),
             ylim   = c(lat_range[1] - lat_pad, lat_range[2] + lat_pad),
             expand = FALSE, default_crs = sf::st_crs(4326)) +
    labs(
      title    = sprintf("b.  Geographic Distribution (%s)", domain_label),
      x = "Longitude", y = "Latitude"
    ) +
    theme_pub() +
    theme(
      axis.title.x     = element_text(size = 7, face = "plain"),
      axis.title.y     = element_text(size = 7, face = "plain"),
      legend.position  = "right",
      legend.box       = "vertical",
      legend.spacing.y = unit(0.5, "cm"),
      legend.title     = element_text(size = 6, face = "bold", lineheight = 1.1),
      legend.text      = element_text(size = 5.5),
      legend.margin    = ggplot2::margin(l = 4),
      plot.margin      = ggplot2::margin(6, 6, 6, 6),
      aspect.ratio = 1 / aspect_ratio
    )

  panel_C
}

panel_C <- build_panel_C(df_landscape_grocery, "Grocery")

print(panel_C)
################################################################################
# 5. COMPOSE FINAL FIGURE
################################################################################

# Use patchwork with a custom layout:
#   Row 1 — top_row (4 cascade plots, legend embedded in A4)
#   Row 2 — Panel B (map)

composite <- (top_row / panel_C) +
  plot_layout(heights = c(0.40, 0.60)) +
  plot_annotation(
    theme = theme(
      plot.margin = ggplot2::margin(6, 4, 6, 4)
    )
  )
print(composite)
################################################################################
# 6. SAVE OUTPUTS
################################################################################

ggsave(file.path(out_dir, "Figure1_GreenIllusion.png"),
       composite, width = 180, height = 200, units = "mm",
       dpi = 600, bg = "white")

ggsave(file.path(out_dir, "Figure1_GreenIllusion.svg"),
       composite, width = 180, height = 200, units = "mm",
       device = svglite, bg = "white")

