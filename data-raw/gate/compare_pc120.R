# Stage 6 gate, plancap side: operative against PC120 on the gate tile, with
# compare_scenarios(), checked against capacityengine's own difference.
#
# Run from the plancap folder, after export_ce_tile.R, export_ce_pc120.R and
#   Rscript data-raw/convert_capacityengine.R ../capacityengine pc120
# then:
#   Rscript data-raw/gate/compare_pc120.R [tile_id]
#
# Both runs with terrain, height surfaces and the measured front yard (the
# "full" mode of compare_tile.R).

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
tile <- if (length(args)) args[1] else "t_011_011"
g <- readRDS(file.path("data-raw/cache", paste0("gate_", tile, ".rds")))
p <- readRDS(file.path("data-raw/cache", paste0("gate_", tile, "_pc120.rds")))
for (nm in names(g$surface_files)) g$layers[[nm]] <- terra::rast(file.path("data-raw/cache", g$surface_files[[nm]]))

as_parcels <- function(s) {
  names(s)[names(s) == "site_id"] <- "parcel_id"
  s$landholding <- s$site_id_parent %||% s$parcel_id
  s[, c("parcel_id", "landholding")]
}
op <- scenario("Operative", rulebook_example("auckland"), parcels = as_parcels(g$sites), roads = g$roads,
               zoning = g$zoning, layers = g$layers, water = g$water, ground = g$ground,
               easements = g$easements, other_parcels = g$other_parcels, buildings = g$buildings,
               streets = g$streets, street_field = "full_road_name", neighbours = g$neighbours,
               landholding = "landholding")
pc <- scenario_change(op, "PC120", rulebook = read_rulebook("data-raw/cache/auckland_pc120.yaml", validate = FALSE),
                      parcels = as_parcels(p$sites), zoning = p$zoning, ground = p$ground)
t0 <- Sys.time()
res <- run_scenarios(scenario_set(op, pc), variant_choice = "standard")
cmp <- compare_scenarios(res, attribution = "sequential", by_rule = FALSE, variant_choice = "standard")
secs <- round(as.numeric(Sys.time() - t0, units = "secs"), 1)

ce_op <- g$ce_terrain
ce_pc <- p$ce
tot <- function(x, col) sum(x[[col]])
cat(sprintf("\nTile %s, operative against PC120 (%.0f s for both runs and the comparison)\n", tile, secs))
for (m in list(c("floor_area", "floorspace_m2"), c("dwellings", "dwellings"))) {
  ce_d <- tot(ce_pc, m[2]) - tot(ce_op, m[2])
  t <- cmp$pairs[[1]]$totals
  pc_d <- t$change[t$measure == m[1]]
  cat(sprintf("%s: capacityengine %s to %s (%+.1f); plancap %s to %s (%+.1f); difference of changes %.3f\n", m[1],
              format(round(tot(ce_op, m[2])), big.mark = ","), format(round(tot(ce_pc, m[2])), big.mark = ","), ce_d,
              format(round(t$baseline[t$measure == m[1]]), big.mark = ","),
              format(round(t$scenario[t$measure == m[1]]), big.mark = ","), pc_d, pc_d - ce_d))
}
# The change on every landholding, against capacityengine's.
par_of <- function(x, s) {
  k <- match(x$site_id, s$site_id)
  pid <- s$site_id_parent[k] %||% x$site_id
  ifelse(is.na(pid), x$site_id, pid)
}
agg <- function(x, s) {
  a <- stats::aggregate(cbind(floor = x$floorspace_m2, dw = x$dwellings), by = list(unit = par_of(x, s)), FUN = sum)
  a
}
a0 <- agg(ce_op, g$sites)
a1 <- agg(ce_pc, p$sites)
ce_u <- merge(a0, a1, by = "unit", all = TRUE, suffixes = c("_op", "_pc"))
ce_u[is.na(ce_u)] <- 0
ce_u$ce_change <- ce_u$floor_pc - ce_u$floor_op
ce_u$ce_dw_change <- ce_u$dw_pc - ce_u$dw_op
st <- sf::st_drop_geometry(cmp$pairs[[1]]$sites)
u <- merge(ce_u, st[, c("unit", "reason", "floor_area_change", "dwellings_change")], by = "unit", all = TRUE)
u$match <- !is.na(u$floor_area_change) & abs(u$floor_area_change - u$ce_change) < 0.01 &
  u$dwellings_change == u$ce_dw_change
cat(sprintf("Landholdings whose change matches capacityengine's (floor area to 0.01 m2, dwellings exactly): %d of %d\n",
            sum(u$match, na.rm = TRUE), nrow(u)))
cat("\nReasons:\n"); print(table(u$reason, useNA = "ifany"))
cat("\nDrivers:\n"); print(cmp$pairs[[1]]$attribution)
cat("\nZone transitions (rezoned land):\n")
tr <- cmp$pairs[[1]]$transitions
print(tr[tr$from != tr$to & tr$land_area > 1, c("from", "to", "land_area", "floor_area_change", "dwellings_change")],
      row.names = FALSE)
cat("\nReconciliation:\n"); print(check_comparison(cmp))
bad <- u[!u$match, ]
if (nrow(bad)) {
  cat("\nLargest differences:\n")
  print(utils::head(bad[order(-abs(bad$floor_area_change - bad$ce_change)),
                        c("unit", "reason", "ce_change", "floor_area_change", "ce_dw_change", "dwellings_change")], 15),
        row.names = FALSE)
}
write.csv(u, file.path("data-raw/cache", paste0("gate_", tile, "_pc120_compare.csv")), row.names = FALSE)
