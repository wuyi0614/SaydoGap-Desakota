###############################################################################
# Figure 2: CTN Puzzle — Forest Plot
#
# What it does:
#   Computes Pearson correlations between nature connectedness (NC) and
#   green-related metrics, then plots them as a forest plot with 95% CIs.
#   Metrics are grouped into four categories:
#   Psychological, Intention, Reported, and Observed (market data).
#
# Input:  data/MergedPanel.csv
# Output: figures/raw/Figure2_CTN_Puzzle.png, figures/raw/Figure2_CTN_Puzzle.svg
###############################################################################

rm(list = ls())

# ── 0. Packages ──────────────────────────────────────────────────────────────

library(ggplot2)
library(dplyr)
library(tidyr)

# ── 1. Data ──────────────────────────────────────────────────────────────────

df <- read.csv("data/MergedPanelV5.csv") %>%
  mutate(country = Country)

df_buyers <- df %>% filter(totalOrders > 1)   # subset for observed behaviour

# ── 2. Colour palette & theme ───────────────────────────────────────────────

col_psych  <- "#D95F02"   # orange
col_say    <- "#1B9E77"   # teal
col_pseudo <- "#7570B3"   # purple
col_actual <- "#E7298A"   # pink

theme_pub <- function(base_size = 7) {
  theme_classic(base_family = "Helvetica", base_size = base_size) %+replace%
    theme(
      plot.background    = element_rect(fill = "white", colour = NA),
      panel.background   = element_rect(fill = "white", colour = NA),
      panel.grid.major   = element_line(colour = "#E5E5E5", linewidth = 0.3),
      panel.grid.minor   = element_blank(),
      axis.line          = element_line(colour = "black", linewidth = 0.4),
      axis.ticks         = element_line(colour = "black", linewidth = 0.3),
      axis.title         = element_text(size = 7,   colour = "black", face = "bold"),
      axis.text          = element_text(size = 6,   colour = "black"),
      plot.title         = element_text(size = 8,   face = "bold", colour = "black",
                                        hjust = 0, margin = ggplot2::margin(b = 4)),
      plot.subtitle      = element_text(size = 6.5, colour = "grey30",
                                        hjust = 0, margin = ggplot2::margin(b = 6)),
      legend.title       = element_text(size = 6.5, face = "bold"),
      legend.text        = element_text(size = 6),
      legend.key.size    = unit(3, "mm"),
      legend.background  = element_rect(fill = NA, colour = NA),
      plot.margin        = ggplot2::margin(5, 5, 5, 5, "pt")
    )
}

# ── 3. Helper: one correlation row ──────────────────────────────────────────

cor_row <- function(data, x, y, label, category, domain = NA_character_) {
  tmp <- na.omit(data[, c(x, y)])
  if (nrow(tmp) < 10 || sd(tmp[[1]]) == 0 || sd(tmp[[2]]) == 0) {
    return(data.frame(Label = label, Category = category, Domain = domain,
                      r = NA_real_, Lower = NA_real_, Upper = NA_real_,
                      p = NA_real_, Sig = "n/a"))
  }
  tt  <- cor.test(tmp[[1]], tmp[[2]])
  sig <- ifelse(tt$p.value < 0.001, "***",
                ifelse(tt$p.value < 0.01, "**",
                       ifelse(tt$p.value < 0.05, "*", "ns")))
  data.frame(Label    = label,
             Category = category,
             Domain   = domain,
             r        = as.numeric(tt$estimate),
             Lower    = tt$conf.int[1],
             Upper    = tt$conf.int[2],
             p        = tt$p.value,
             Sig      = sig)
}

# ── 4. Compute correlations by category ─────────────────────────────────────

# 4a. Psychological (NC → SEP / HHE)
rows_psych <- bind_rows(
  cor_row(df, "genGreenConnectness", "genGreenAttitude",     "Support Environ.\nProtection Action", "Psychological"),
  cor_row(df, "genGreenConnectness", "genGreenHumanLikert",  "Humans Are\nHarming Environ.", "Psychological")
)

# 4b. Intention (NC → stated-intention Likert)
rows_intention <- bind_rows(
  cor_row(df, "genGreenConnectness", "stdGreenGroceryLikert",    "Grocery",     "Intention"),
  cor_row(df, "genGreenConnectness", "stdGreenElectronicLikert", "Electronics", "Intention"),
  cor_row(df, "genGreenConnectness", "stdGreenDeliveryLikert",   "Delivery",    "Intention"),
  cor_row(df, "genGreenConnectness", "stdGreenWalkLikert",       "Transport",   "Intention")
)

# 4c. Reported (NC → self-reported behaviour)
rows_reported <- bind_rows(
  cor_row(df, "genGreenConnectness", "reportMonthlyGreenGrocery",    "Grocery",     "Reported"),
  cor_row(df, "genGreenConnectness", "reportMonthlyGreenElectronic", "Electronics", "Reported"),
  cor_row(df, "genGreenConnectness", "reportMonthlyGreenDelivery",   "Delivery",    "Reported"),
  cor_row(df, "genGreenConnectness", "reportMonthlyGreenWalk",       "Transport",   "Reported")
)

# 4d. Observed (NC → market data, Grocery vs Electronics)
actual_vars <- list(
  "Spending Share"   = c("greenSpendingShareGrocery",   "greenSpendingShareElectronic"),
  "Item Share"       = c("greenItemsShareGrocery",      "greenItemsShareElectronic"),
  "Per-capita Spend" = c("greenMonthlySpendingGrocery", "greenMonthlySpendingElectronic"),
  "Order Share"      = c("greenOrdersShareGrocery",     "greenOrdersShareElectronic")
)

rows_observed <- lapply(names(actual_vars), function(metric) {
  v <- actual_vars[[metric]]
  bind_rows(
    cor_row(df_buyers, "genGreenConnectness", v[1],
            metric, "Observed", domain = "Grocery"),
    cor_row(df_buyers, "genGreenConnectness", v[2],
            metric, "Observed", domain = "Electronics")
  )
}) %>% bind_rows()

# ── 5. Assemble plot data ───────────────────────────────────────────────────

plot_df <- bind_rows(rows_psych, rows_intention, rows_reported, rows_observed)

# Category factor (controls legend order)
plot_df$Category <- factor(
  plot_df$Category,
  levels = c("Psychological", "Intention", "Reported", "Observed")
)

# Unique y-axis labels (duplicate names like "Grocery" across categories)
plot_df$DisplayLabel <- plot_df$Label
plot_df$Label        <- make.unique(as.character(plot_df$Label), sep = "__")
plot_df$Label        <- factor(plot_df$Label, levels = rev(plot_df$Label))

# Right-hand annotation: r + significance stars
plot_df$pLabel <- ifelse(
  is.na(plot_df$p), "",
  paste0("r = ", formatC(plot_df$r, format = "f", digits = 2), "  ", plot_df$Sig)
)

# Dotted separators between category blocks
sep_y <- c(
  nrow(rows_observed)                                  + 0.5,
  nrow(rows_observed) + nrow(rows_reported)            + 0.5,
  nrow(rows_observed) + nrow(rows_reported) + nrow(rows_intention) + 0.5
)

# ── 6. Legend key: unified colour + shape ────────────────────────────────────
#    5 entries — Observed split into Grocery (circle) & Electronics (triangle)

plot_df$Domain[is.na(plot_df$Domain)] <- "Other"

plot_df$LegendKey <- as.character(plot_df$Category)
plot_df$LegendKey[plot_df$Category == "Observed" &
                    plot_df$Domain == "Grocery"]     <- "Observed: Grocery"
plot_df$LegendKey[plot_df$Category == "Observed" &
                    plot_df$Domain == "Electronics"] <- "Observed: Electronics"

plot_df$LegendKey <- factor(
  plot_df$LegendKey,
  levels = c("Psychological", "Intention", "Reported",
             "Observed: Grocery", "Observed: Electronics")
)

legend_colours <- c(
  "Psychological"         = col_psych,
  "Intention"             = col_say,
  "Reported"              = col_pseudo,
  "Observed: Grocery"     = col_actual,
  "Observed: Electronics" = col_actual
)

legend_shapes <- c(
  "Psychological"         = 16,
  "Intention"             = 16,
  "Reported"              = 16,
  "Observed: Grocery"     = 16,   # circle
  "Observed: Electronics" = 17    # triangle
)

# ── 7. Build plot ────────────────────────────────────────────────────────────

fig <- ggplot(plot_df, aes(x = r, y = Label,
                           colour = LegendKey, shape = LegendKey)) +
  geom_vline(xintercept = 0, linetype = "dashed",
             colour = "grey50", linewidth = 0.3) +
  geom_hline(yintercept = sep_y, linetype = "dotted",
             colour = "grey80", linewidth = 0.3) +
  geom_errorbarh(aes(xmin = Lower, xmax = Upper),
                 height = 0.25, linewidth = 0.45) +
  geom_point(size = 2.2) +
  geom_text(aes(label = pLabel, x = Upper + 0.008),
            hjust = 0, size = 1.9, show.legend = FALSE) +
  scale_colour_manual(values = legend_colours,
                      guide  = guide_legend(nrow = 1)) +
  scale_shape_manual(values  = legend_shapes,
                     guide   = guide_legend(nrow = 1)) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.20))) +
  scale_y_discrete(labels = setNames(plot_df$DisplayLabel, plot_df$Label)) +
  labs(x = "Pearson r", y = NULL, colour = NULL, shape = NULL) +
  theme_pub() +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position    = "bottom",
    legend.margin      = ggplot2::margin(2, 0, 0, 0),
    legend.key.size    = unit(3.5, "mm"),
    legend.text        = element_text(size = 5.5)
  )

# ── 8. Save ──────────────────────────────────────────────────────────────────

out_dir <- "figures/raw"
dir.create(file.path(out_dir, "png"), showWarnings = FALSE, recursive = TRUE)

ggsave(file.path(out_dir, "Figure2_CTN_Puzzle.png"), fig,
       width = 130, height = 120, units = "mm", dpi = 300)

if (requireNamespace("svglite", quietly = TRUE)) {
  dir.create(file.path(out_dir, "svg"), showWarnings = FALSE, recursive = TRUE)
  ggsave(file.path(out_dir, "Figure2_CTN_Puzzle.svg"), fig,
         width = 130, height = 120, units = "mm",
         device = svglite::svglite, bg = "white")
}
