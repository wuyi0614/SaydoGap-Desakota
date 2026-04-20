################################################################################
# Supp. Figure 1: Geographic Distribution — Electronic Domain
#
# What it does:
#   Produces the geographic distribution map for the Electronic domain,
#   mirroring the Grocery map in Figure 1 Panel B.
#
# Input:  None (uses in-memory objects from Figure1.R)
# Output: figures/raw/SFig1_landscape.png, figures/raw/SFig1_landscape.svg
#
# Dependency: Run Figure1.R (sections 1-2) first in the SAME R session.
#   Required objects:
#     - df                      (master data frame)
#     - df_landscape_electronic (from build_landscape_wide())
#     - theme_pub()             (custom ggplot2 theme)
#     - coords_matched          (city coordinates from GeoIndex_V6.xlsx)
################################################################################

# ── Output directories ────────────────────────────────────────────────────────
out_dir <- "figures/raw"
dir.create(file.path(out_dir, "png"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(out_dir, "svg"), showWarnings = FALSE, recursive = TRUE)

################################################################################
# build_panel_C() — identical to the version in 1Green_Illusion.R
# (reproduced here so this script is self-contained once the data objects
#  listed above are available)
################################################################################

build_panel_C <- function(df_landscape_domain, domain_label = "Grocery") {

  df_geo <- df_landscape_domain %>%
    filter(!is.na(latitude) & !is.na(longitude))

  # ── Spatial autocorrelation (Moran's I) ─────────────────────────────────────
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

  # ── Base map ─────────────────────────────────────────────────────────────────
  world         <- ne_countries(scale = "medium", returnclass = "sf")
  sea_countries <- c("Indonesia", "Malaysia", "Philippines",
                     "Singapore", "Thailand", "Vietnam")
  sea_map       <- world %>% filter(name %in% sea_countries |
                                      admin %in% sea_countries)

  lon_range <- range(df_geo$longitude, na.rm = TRUE)
  lat_range <- range(df_geo$latitude,  na.rm = TRUE)
  lon_pad   <- diff(lon_range) * 0.05
  lat_pad   <- diff(lat_range) * 0.05

  # ── Cities to label (capital cities only) ───────────────────────────────────
  capitals        <- df_geo %>% filter(!is.na(isCapitalCity) & isCapitalCity == 1)
  cities_to_label <- capitals %>%
    distinct(city, country, .keep_all = TRUE)

  # ── Color palette (same green–red ramp as original) ─────────────────────────
  map_color_palette <- c("#006837", "#1a9850", "#66bd63",
                         "#fee08b", "#f46d43", "#d73027", "#a50026")

  # ── Build map ────────────────────────────────────────────────────────────────
  panel_B <- ggplot() +
    geom_rect(aes(xmin = lon_range[1] - lon_pad, xmax = lon_range[2] + lon_pad,
                  ymin = lat_range[1] - lat_pad, ymax = lat_range[2] + lat_pad),
              fill = "#D6EAF8", alpha = 0.3) +
    geom_sf(data = sea_map, fill = "#F5F5DC", color = "grey60", linewidth = 0.3) +
    # Points: color = LPM Reporting Bias, size = BPN Reporting Bias
    geom_point(data = df_geo %>% filter(!is.na(Gap2_SayDo_LPM)),
               aes(x = longitude, y = latitude,
                   color = Gap2_SayDo_LPM, size = Gap2_SayDo_BPN),
               alpha = 0.8, shape = 16) +
    # Grey points where LPM is missing
    geom_point(data = df_geo %>% filter(is.na(Gap2_SayDo_LPM)),
               aes(x = longitude, y = latitude, size = Gap2_SayDo_BPN),
               color = "grey50", alpha = 0.6, shape = 16) +
    # Moran's I annotations
    annotate("text", x = 98, y = -6,
             label = sprintf("BPN Moran's I = %.3f%s",
                             moran_BPN$estimate[1], sig_stars(moran_BPN$p.value)),
             size = 2.5, color = "#B22222", fontface = "bold") +
    annotate("text", x = 98, y = -8,
             label = sprintf("LPM Moran's I = %.3f%s",
                             moran_LPM$estimate[1], sig_stars(moran_LPM$p.value)),
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
      aspect.ratio     = 1 / aspect_ratio
    )

  panel_B
}

################################################################################
# Build Panel B for ELECTRONIC
################################################################################

panel_B_electronic <- build_panel_C(df_landscape_electronic, "Electronic")

print(panel_B_electronic)

################################################################################
# Save outputs
################################################################################

ggsave(
  filename = file.path(out_dir, "SFig1_landscape.png"),
  plot     = panel_B_electronic,
  width    = 180, height = 110, units = "mm",
  dpi      = 600, bg = "white"
)

ggsave(
  filename = file.path(out_dir, "SFig1_landscape.svg"),
  plot     = panel_B_electronic,
  width    = 180, height = 110, units = "mm",
  device   = svglite, bg = "white"
)
