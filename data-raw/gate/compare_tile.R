# Stage 4 gate, plancap side: run plancap on a capacityengine tile's own
# inputs and compare site by site with capacityengine's results.
#
# Run from the plancap folder, after export_ce_tile.R:
#   Rscript data-raw/gate/compare_tile.R [tile_id] [flat|nofront|terrain|full|published]
#
# Modes (capacityengine run compared): flat (flat ground, front yard measured
# from the neighbours' houses), nofront (flat, no measured front yard),
# terrain (terrain and height surfaces, no measured front yard), full
# (terrain, surfaces and the measured front yard), published (the published
# region run's rows).
#
# Writes data-raw/cache/gate_<tile>_<mode>.csv (one row per site) and prints a
# reconciliation summary.

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
tile <- if (length(args)) args[1] else "t_011_011"
mode <- if (length(args) > 1) args[2] else "flat"
g <- readRDS(file.path("data-raw/cache", paste0("gate_", tile, ".rds")))
ce <- switch(mode, flat = g$ce_flat, nofront = g$ce_flat_nofront, published = g$ce_published,
             terrain = g$ce_terrain_nofront, full = g$ce_terrain)
terrain <- mode %in% c("published", "terrain", "full")
front <- mode %in% c("flat", "published", "full")

rb <- rulebook_example("auckland")
parcels <- g$sites
names(parcels)[names(parcels) == "site_id"] <- "parcel_id"
# Height surfaces need terrain (they are absolute elevations): with ground
# levels, swap each surface's extent polygons for its raster.
if (terrain) {
  for (nm in names(g$surface_files)) {
    g$layers[[nm]] <- terra::rast(file.path("data-raw/cache", g$surface_files[[nm]]))
  }
}
# Published results include terrain: give plancap the same ground levels.
# capacityengine's zone-split pieces of one parcel are one landholding.
parcels$landholding <- parcels$site_id_parent %||% parcels$parcel_id
sc <- scenario(paste("AKL", tile), rb, parcels = parcels[, c("parcel_id", "landholding")], roads = g$roads,
               zoning = g$zoning, layers = g$layers, water = g$water,
               ground = if (terrain) g$ground, easements = g$easements, other_parcels = g$other_parcels,
               buildings = if (front) g$buildings, streets = if (front) g$streets,
               street_field = "full_road_name", neighbours = g$neighbours, landholding = "landholding")
t0 <- Sys.time()
cap <- suppressWarnings(estimate_capacity(sc, variant_choice = "standard"))
secs <- round(as.numeric(Sys.time() - t0, units = "secs"), 1)

pc <- sf::st_drop_geometry(cap$sites)
pc$ce_id <- pc$parent_id
agg <- stats::aggregate(cbind(floor_area, residential_floor_area, dwellings) ~ ce_id, data = pc, FUN = sum)
m <- merge(data.frame(site_id = ce$site_id, zone_key = ce$zone_key, ce_floor = ce$floorspace_m2,
                      ce_res = ce$residential_m2, ce_dw = ce$dwellings, ce_path = ce$yield_path,
                      ce_storeys = ce$storeys_effective, stringsAsFactors = FALSE),
           agg, by.x = "site_id", by.y = "ce_id", all = TRUE)
info <- pc[!duplicated(pc$ce_id), c("ce_id", "path", "storeys", "envelope_binding", "dwelling_binding", "flag")]
m <- merge(m, info, by.x = "site_id", by.y = "ce_id", all.x = TRUE)
m$d_floor <- m$floor_area - m$ce_floor
m$d_dw <- m$dwellings - m$ce_dw
m$match_floor <- !is.na(m$d_floor) & abs(m$d_floor) < 0.01
m$match_dw <- !is.na(m$d_dw) & m$d_dw == 0
write.csv(m, file.path("data-raw/cache", paste0("gate_", tile, "_", mode, ".csv")), row.names = FALSE)

cat(sprintf("\nTile %s, capacityengine %s: %d sites; plancap %.1f s\n", tile, mode, nrow(ce), secs))
cat(sprintf("Floor area: capacityengine %s m2, plancap %s m2 (%+.3f%%)\n",
            format(round(sum(m$ce_floor, na.rm = TRUE)), big.mark = ","),
            format(round(sum(m$floor_area, na.rm = TRUE)), big.mark = ","),
            100 * (sum(m$floor_area, na.rm = TRUE) / sum(m$ce_floor, na.rm = TRUE) - 1)))
cat(sprintf("Dwellings:  capacityengine %d, plancap %d (%+.3f%%)\n", sum(m$ce_dw, na.rm = TRUE),
            sum(m$dwellings, na.rm = TRUE), 100 * (sum(m$dwellings, na.rm = TRUE) / sum(m$ce_dw, na.rm = TRUE) - 1)))
cat(sprintf("Sites matching floor area to 0.01 m2: %d of %d (%.1f%%); dwellings exactly: %d (%.1f%%)\n",
            sum(m$match_floor), nrow(m), 100 * mean(m$match_floor), sum(m$match_dw), 100 * mean(m$match_dw)))
cat("\nBy zone (floor area difference, m2; sites not matching):\n")
bz <- stats::aggregate(cbind(d_floor = m$d_floor, d_dw = m$d_dw, miss = !m$match_floor) ~ zone_key,
                       data = m, FUN = sum, na.action = na.pass)
print(bz[order(-abs(bz$d_floor)), ], row.names = FALSE)
cat("\nPaths (capacityengine vs plancap):\n")
print(table(ce = m$ce_path, plancap = m$path, useNA = "ifany"))
cat("\nLargest floor area differences:\n")
print(utils::head(m[order(-abs(m$d_floor)), c("site_id", "zone_key", "ce_floor", "floor_area", "ce_storeys",
                                              "storeys", "envelope_binding", "path")], 15), row.names = FALSE)
