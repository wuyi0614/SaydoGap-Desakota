################################################################################
# Figure 5: Zonal Classification of Cities
#
# What it does:
#   Classifies cities into three urban zones based on Green Exposure and
#   Desakota indices, then visualises behavioral differences across zones.
#   Panel 5a (scatter): City positions in Green Exposure × Desakota space
#   Panel 5b (bar chart): Mean z-scored outcomes by zone
#   Panel 5c (pie charts): Zone composition
#
# Input:  data/IncludingLogData.csv
# Output: figures/Figure5_Zonal_Master_{DOMAIN}.png
#         figures/Figure5_Zonal_Master_{DOMAIN}.svg
#
# Dependency: Run STable18_tranformation.R first (generates input CSV).
################################################################################
rm(list = ls())
library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(ggrepel)
library(readr)
library(cowplot)

# ══════════════════════════════════════════════════════════════════════════════
# USER-DEFINED SETTINGS
# ══════════════════════════════════════════════════════════════════════════════

DOMAIN <- "Grocery"   # "Grocery" or "Electronic"

THRESH_DESAKOTA <- 0
THRESH_GREEN    <- 0

domain_vars <- list(
  Grocery = list(
    gap1  = "Gap1_Grocery_LPM",
    gap2  = "Gap2_Grocery_LPM",
    spend = "greenSpendingShareGrocery_LPM"
  ),
  Electronic = list(
    gap1  = "Gap1_Electronic_LPM",
    gap2  = "Gap2_Electronic_LPM",
    spend = "greenSpendingShareElectronic_LPM"
  )
)

dv <- domain_vars[[DOMAIN]]


# ══════════════════════════════════════════════════════════════════════════════
# Step 0. Load & clean
# ══════════════════════════════════════════════════════════════════════════════

df <- read.csv("data/IncludingLogData.csv")

# Remove aggregate rows that are not real cities
df <- df %>%
  filter(!grepl("&", city),
         !grepl("(?i)^other$", city, perl = TRUE),
         !is.na(city), city != "")

# Compute LPM gap columns
df <- df %>%
  mutate(
    Gap1_Grocery_LPM    = stdGreenGroceryLikert_LPM    - reportMonthlyGreenGrocery_LPM,
    Gap2_Grocery_LPM    = reportMonthlyGreenGrocery_LPM - greenSpendingShareGrocery_LPM,
    Gap1_Electronic_LPM = stdGreenElectronicLikert_LPM  - reportMonthlyGreenElectronic_LPM,
    Gap2_Electronic_LPM = reportMonthlyGreenElectronic_LPM - greenSpendingShareElectronic_LPM
  )

# ── Panel 5a & 5c sample: only spatial indices required ──────────────────────
spatial_vars <- c("Green.Exposure.Index", "Desakota_Index_CropOnly_log")
meta_vars    <- c("city", "country", "isCapitalCity")

df_spatial <- df %>%
  dplyr::select(all_of(c(meta_vars, spatial_vars))) %>%
  tidyr::drop_na()

cat("\n=======================================================\n")
cat("Panel 5a & 5c sample (spatial only): N =", nrow(df_spatial), "\n")

# ── Panel 5b sample: additionally requires LPM outcomes ──────────────────────
outcome_vars <- c(
  "Gap1_Grocery_LPM",    "Gap2_Grocery_LPM",    "greenSpendingShareGrocery_LPM",
  "Gap1_Electronic_LPM", "Gap2_Electronic_LPM", "greenSpendingShareElectronic_LPM"
)

df_outcome <- df %>%
  dplyr::select(all_of(c(meta_vars, spatial_vars, outcome_vars))) %>%
  tidyr::drop_na()

cat("Panel 5b sample (spatial + outcome): N =", nrow(df_outcome), "\n")
cat("=======================================================\n\n")


# ══════════════════════════════════════════════════════════════════════════════
# Step 1. Z-score and zonal classification (applied to each sample separately)
# ══════════════════════════════════════════════════════════════════════════════

classify_zones <- function(data, cols_to_z) {
  data[cols_to_z] <- lapply(data[cols_to_z], function(x) as.numeric(scale(x)))
  data %>%
    mutate(
      Urban_Zone = case_when(
        Desakota_Index_CropOnly_log > THRESH_DESAKOTA                                         ~ "Integrated Desakota cities",
        Desakota_Index_CropOnly_log <= THRESH_DESAKOTA & Green.Exposure.Index > THRESH_GREEN  ~ "Aesthetic Green cities",
        Desakota_Index_CropOnly_log <= THRESH_DESAKOTA & Green.Exposure.Index <= THRESH_GREEN ~ "Grey Infrastructure cities"
      ),
      Urban_Zone = factor(Urban_Zone, levels = c(
        "Aesthetic Green cities",
        "Grey Infrastructure cities",
        "Integrated Desakota cities"
      ))
    )
}

# Panels 5a & 5c — z-score spatial vars only
df_zones_spatial <- classify_zones(df_spatial, spatial_vars)

# Panel 5b — z-score spatial + outcome vars (consistent z-scoring within sample)
df_zones_outcome <- classify_zones(df_outcome, c(spatial_vars, outcome_vars))


# ══════════════════════════════════════════════════════════════════════════════
# Colors
# ══════════════════════════════════════════════════════════════════════════════

zone_colors <- c(
  "Aesthetic Green cities"      = "#2E8B4A",
  "Grey Infrastructure cities"  = "#8D8D8D",
  "Integrated Desakota cities"  = "#E07B3A"
)

country_colors <- c(
  "Indonesia"   = "#C0392B",
  "Malaysia"    = "#1A5EA8",
  "Philippines" = "#8E44AD",
  "Singapore"   = "#F1C40F",
  "Thailand"    = "#17A589",
  "Vietnam"     = "#2C3E50"
)

df_capitals <- df_zones_spatial %>% filter(isCapitalCity == 1)


# ══════════════════════════════════════════════════════════════════════════════
# 2. Panel 5a: Scatter Plot (uses df_zones_spatial)
# ══════════════════════════════════════════════════════════════════════════════

p_5a <- ggplot(df_zones_spatial, aes(x = Desakota_Index_CropOnly_log, y = Green.Exposure.Index)) +
  
  annotate("rect", xmin = THRESH_DESAKOTA, xmax = Inf,  ymin = -Inf, ymax = Inf,
           fill = zone_colors["Integrated Desakota cities"], alpha = 0.1) +
  annotate("rect", xmin = -Inf, xmax = THRESH_DESAKOTA, ymin = THRESH_GREEN, ymax = Inf,
           fill = zone_colors["Aesthetic Green cities"], alpha = 0.1) +
  annotate("rect", xmin = -Inf, xmax = THRESH_DESAKOTA, ymin = -Inf, ymax = THRESH_GREEN,
           fill = zone_colors["Grey Infrastructure cities"], alpha = 0.1) +
  
  geom_hline(yintercept = THRESH_GREEN,    linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = THRESH_DESAKOTA, linetype = "dashed", color = "grey50") +
  
  geom_point(aes(fill = country, color = Urban_Zone),
             shape = 21, stroke = 1.2, alpha = 0.85, size = 3) +
  scale_fill_manual(values = country_colors, name = "Country") +
  scale_color_manual(values = zone_colors,   name = "Urban Typology") +
  
  geom_text_repel(data = df_capitals,
                  aes(label = city),
                  size = 3.2, color = "black",
                  box.padding = 0.5, point.padding = 0.3,
                  segment.color = "grey50", min.segment.length = 0,
                  max.overlaps = Inf) +
  
  annotate("text",
           x = max(df_zones_spatial$Desakota_Index_CropOnly_log, na.rm = TRUE) * 0.95,
           y = min(df_zones_spatial$Green.Exposure.Index, na.rm = TRUE) * 0.95,
           label = "Integrated Desakota cities", fontface = "bold",
           color = zone_colors["Integrated Desakota cities"], hjust = 1, size = 5) +
  annotate("text",
           x = min(df_zones_spatial$Desakota_Index_CropOnly_log, na.rm = TRUE) * 0.95,
           y = max(df_zones_spatial$Green.Exposure.Index, na.rm = TRUE) * 0.95,
           label = "Aesthetic Green cities", fontface = "bold",
           color = zone_colors["Aesthetic Green cities"], hjust = 0, size = 5) +
  annotate("text",
           x = min(df_zones_spatial$Desakota_Index_CropOnly_log, na.rm = TRUE) * 0.95,
           y = min(df_zones_spatial$Green.Exposure.Index, na.rm = TRUE) * 0.95,
           label = "Grey Infrastructure cities", fontface = "bold",
           color = zone_colors["Grey Infrastructure cities"], hjust = 0, size = 5) +
  
  labs(
    tag   = "a",
    title = "Morphological Classification",
    x     = "Desakota Index (Z-Score)",
    y     = "Green Exposure Index (Z-Score)"
  ) +
  guides(
    fill  = guide_legend(
      title = "Country",
      override.aes = list(shape = 21, size = 4, color = "black", stroke = 0.5)
    ),
    color = guide_legend(
      title = "Urban Typology",
      override.aes = list(shape = 22, size = 5, fill = zone_colors, color = "black", stroke = 0.5)
    )
  ) +
  theme_bw(base_size = 11, base_family = "sans") +
  theme(
    panel.grid      = element_blank(),
    legend.position = "bottom",
    legend.title    = element_text(size = 10),
    legend.text     = element_text(size = 9),
    legend.margin   = ggplot2::margin(t = 5),
    plot.title      = element_text(size = 11, hjust = 0.5, margin = ggplot2::margin(b = 5)),
    plot.tag        = element_text(size = 14),
    axis.title      = element_text(size = 10),
    axis.text       = element_text(size = 9)
  )


# ══════════════════════════════════════════════════════════════════════════════
# 3. Panel 5b: Behavioral Profiles Bar Chart (uses df_zones_outcome)
# ══════════════════════════════════════════════════════════════════════════════

zone_summary <- df_zones_outcome %>%
  group_by(Urban_Zone) %>%
  summarize(
    `Reported Gap`             = mean(.data[[dv$gap1]],  na.rm = TRUE),
    `Reporting Bias`           = mean(.data[[dv$gap2]],  na.rm = TRUE),
    `Observed Market Behavior` = mean(.data[[dv$spend]], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols      = c(`Reported Gap`, `Reporting Bias`, `Observed Market Behavior`),
    names_to  = "Behavioral_Metric",
    values_to = "Average_Z_Score"
  ) %>%
  mutate(
    Behavioral_Metric = factor(Behavioral_Metric, levels = c(
      "Reported Gap", "Reporting Bias", "Observed Market Behavior"
    ))
  )

p_5b <- ggplot(zone_summary,
               aes(x = Behavioral_Metric, y = Average_Z_Score, fill = Urban_Zone)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.8) +
  geom_bar(stat = "identity",
           position = position_dodge(width = 0.8),
           width = 0.7, color = "black", linewidth = 0.3) +
  scale_fill_manual(values = zone_colors, name = "Urban Typology") +
  labs(
    tag   = "b",
    title = "Behavioral Profiles by Zone",
    x     = NULL,
    y     = "Average Z-Score"
  ) +
  theme_classic(base_size = 11, base_family = "sans") +
  theme(
    panel.grid   = element_blank(),
    legend.position = "none",
    axis.text.x  = element_text(size = 9, color = "black"),
    axis.text.y  = element_text(size = 9),
    axis.title.y = element_text(size = 10, margin = ggplot2::margin(r = 10)),
    plot.title   = element_text(size = 11, hjust = 0.5, margin = ggplot2::margin(b = 5)),
    plot.tag     = element_text(size = 14)
  )


# ══════════════════════════════════════════════════════════════════════════════
# 4. Panel 5c: Country Pie Charts (uses df_zones_spatial)
# ══════════════════════════════════════════════════════════════════════════════

pie_data <- df_zones_spatial %>%
  group_by(country, Urban_Zone) %>%
  summarize(n_cities = n(), .groups = "drop") %>%
  group_by(country) %>%
  mutate(
    total = sum(n_cities),
    pct   = n_cities / total * 100,
    label = ifelse(pct >= 5, paste0(n_cities, "\n(", round(pct, 0), "%)"), "")
  ) %>%
  ungroup() %>%
  tidyr::complete(country, Urban_Zone, fill = list(n_cities = 0, total = 0, pct = 0, label = "")) %>%
  group_by(country) %>%
  mutate(total = sum(n_cities)) %>%
  ungroup() %>%
  arrange(country, Urban_Zone) %>%
  group_by(country) %>%
  mutate(
    cum_pct = cumsum(pct),
    mid_pct = cum_pct - pct / 2
  ) %>%
  ungroup()

p_5c <- ggplot(pie_data, aes(x = "", y = pct, fill = Urban_Zone)) +
  geom_bar(stat = "identity", width = 1, color = "white", linewidth = 0.6) +
  coord_polar(theta = "y") +
  facet_wrap(~ country, nrow = 2, ncol = 3) +
  geom_text(aes(y = mid_pct, label = label),
            size = 2.8, color = "white", lineheight = 0.85) +
  scale_fill_manual(values = zone_colors, name = "Urban Typology") +
  labs(tag = "c", title = "City Composition by Country") +
  theme_void(base_size = 11, base_family = "sans") +
  theme(
    plot.title      = element_text(size = 11, hjust = 0.5, margin = ggplot2::margin(b = 5)),
    plot.tag        = element_text(size = 14),
    legend.position = "none",
    strip.text      = element_text(size = 9, margin = ggplot2::margin(b = 3)),
    plot.margin     = ggplot2::margin(5, 5, 5, 5)
  )


# ══════════════════════════════════════════════════════════════════════════════
# 5. Shared bottom legends
# ══════════════════════════════════════════════════════════════════════════════

legend_extractor_zone <- ggplot(zone_summary,
                                aes(x = Behavioral_Metric, y = Average_Z_Score, fill = Urban_Zone)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = zone_colors, name = "Urban Typology") +
  guides(fill = guide_legend(title = "Urban Typology", override.aes = list(size = 5))) +
  theme(
    legend.position   = "bottom",
    legend.title      = element_text(size = 11, face = "bold"),
    legend.text       = element_text(size = 10),
    legend.key.size   = unit(0.55, "cm"),
    legend.margin     = ggplot2::margin(0, 0, 0, 0),
    legend.box.margin = ggplot2::margin(0, 0, 0, 0)
  )
legend_zone <- cowplot::get_legend(legend_extractor_zone)

legend_extractor_country <- ggplot(df_zones_spatial,
                                   aes(x = Desakota_Index_CropOnly_log,
                                       y = Green.Exposure.Index,
                                       fill = country)) +
  geom_point(shape = 21, size = 3, color = "black") +
  scale_fill_manual(values = country_colors, name = "Country") +
  guides(fill = guide_legend(
    title = "Country",
    override.aes = list(shape = 21, size = 4, color = "black", stroke = 0.5)
  )) +
  theme(
    legend.position   = "bottom",
    legend.title      = element_text(size = 11, face = "bold"),
    legend.text       = element_text(size = 10),
    legend.key.size   = unit(0.55, "cm"),
    legend.margin     = ggplot2::margin(0, 0, 0, 0),
    legend.box.margin = ggplot2::margin(0, 0, 0, 0)
  )
legend_country <- cowplot::get_legend(legend_extractor_country)

combined_legend <- cowplot::plot_grid(
  legend_country, legend_zone,
  nrow = 1, rel_widths = c(1, 1)
)


# ══════════════════════════════════════════════════════════════════════════════
# 6. Assembly
# ══════════════════════════════════════════════════════════════════════════════

p_5a_noleg <- p_5a + theme(legend.position = "none")

right_col   <- p_5b / p_5c + plot_layout(heights = c(1, 1.4))
main_panels <- (p_5a_noleg | right_col) + plot_layout(widths = c(2, 1))
main_grob   <- patchwork::patchworkGrob(main_panels)

composite_final <- cowplot::plot_grid(
  main_grob,
  combined_legend,
  ncol        = 1,
  rel_heights = c(10, 1)
)

ggsave(
  paste0("figures/Figure5_Zonal_Master_", DOMAIN, ".png"),
  composite_final,
  width = 16, height = 10, units = "in", dpi = 600
)

ggsave(
  paste0("figures/Figure5_Zonal_Master_", DOMAIN, ".svg"),
  composite_final,
  width = 16, height = 10, units = "in"
)

