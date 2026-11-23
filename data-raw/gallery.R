# Render every plancap plot on Exampleton and its Plan Change 1, for review.
#
# Run from the package root:  Rscript data-raw/gallery.R
# Writes PNGs to data-raw/gallery/ (git-ignored).

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
out <- "data-raw/gallery"
dir.create(out, showWarnings = FALSE)
town <- exampleton()
pc1 <- exampleton_pc1()
base <- scenario("Exampleton operative", rulebook_example("exampleton"),
                 parcels = town$parcels[town$parcels$parcel_type == "land", ],
                 roads = town$parcels[town$parcels$parcel_type == "road", ],
                 zoning = town$zoning,
                 layers = town[c("height_areas", "flood_hazard", "heritage", "trees", "precincts", "transit")],
                 water = town$water, centrelines = town$road_centrelines)
change <- scenario_change(base, "PC1 as notified", rulebook = pc1$rulebook, zoning = pc1$zoning,
                          layers = list(flood_hazard = pc1$flood_hazard),
                          parcels = pc1$parcels[pc1$parcels$parcel_type == "land", ])
cache <- file.path(out, "gallery_cache.rds")
if (file.exists(cache)) {
  z <- readRDS(cache)
} else {
  res <- run_scenarios(scenario_set(base, change))
  z <- list(cap = res[[1]], cmp = compare_scenarios(res, grid = 200),
            sens = sensitivity(base, "zones.MDR.ratios.coverage_max.value", c(0.3, 0.4, 0.5, 0.6, 0.7), by = "zone"))
  saveRDS(z, cache)
}
cap <- z$cap
cmp <- z$cmp
save <- function(p, name, w = 8, h = 5) {
  f <- file.path(out, paste0(name, ".png"))
  ggplot2::ggsave(f, p, width = w, height = h, dpi = 150, device = ragg::agg_png)
  cat("wrote", f, "\n")
}
site <- cap$sites$site_id[which.max(cap$sites$floor_area * (cap$sites$zone_key %in% "MDR"))]
save(plot_capacity(cap), "01_capacity_by_zone")
save(plot_capacity(cap, measure = "dwellings", fill = "height_band"), "02_dwellings_by_zone_and_height")
save(plot_height_profile(cap, by = "zone"), "03_height_profile")
save(plot_distribution(cap), "04_distribution", w = 9, h = 5.5)
save(plot_constraints(cap), "05_constraints")
save(plot_capacity_map(cap), "06_map_sites", w = 7, h = 6.5)
save(plot_capacity_map(cap, grid = 100), "07_map_grid", w = 7, h = 6.5)
save(plot_cumulative(cap, by = "zone"), "08_cumulative", w = 6.5, h = 6.5)
save(plot_site(cap, site), "09_site_plan", w = 7, h = 6)
save(plot_site(cap, site, view = "axo"), "10_site_axo", w = 7, h = 6)
save(plot_comparison(cmp), "11_comparison_dumbbell")
save(plot_comparison(cmp, measure = "dwellings", type = "bars"), "12_comparison_bars")
save(plot_change_map(cmp), "13_change_map_sites", w = 7, h = 6.5)
save(plot_change_map(cmp, on = "grid"), "14_change_map_grid", w = 7, h = 6.5)
save(plot_transitions(cmp), "15_transitions", w = 7, h = 5.5)
save(plot_attribution(cmp), "16_attribution")
save(plot_attribution(cmp, by_rule = TRUE, measure = "dwellings"), "17_attribution_by_rule")
save(plot_sensitivity(z$sens, measure = "dwellings"), "18_sensitivity")
save(autoplot(cap), "19_dashboard", w = 12, h = 9)
save(plot_capacity(cap, mode = "dark"), "20_dark_capacity")
save(plot_change_map(cmp, on = "grid", mode = "dark"), "21_dark_change_map", w = 7, h = 6.5)
save(plot_site(cap, site, view = "axo", mode = "dark"), "22_dark_site_axo", w = 7, h = 6)
