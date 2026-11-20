# Gate debugging, plancap side: the same sites on the same inputs.
#   Rscript data-raw/gate/debug_sites_pc.R t_011_011 S051662 S191701
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
a <- commandArgs(trailingOnly = TRUE)
tile <- a[1]
ids <- a[-1]
g <- readRDS(file.path("data-raw/cache", paste0("gate_", tile, ".rds")))
parcels <- g$sites[g$sites$site_id %in% ids, ]
names(parcels)[names(parcels) == "site_id"] <- "parcel_id"
# Neighbouring sites matter for classification: keep everything within 60 m.
near <- g$sites[lengths(sf::st_is_within_distance(g$sites, parcels, 60)) > 0, ]
names(near)[names(near) == "site_id"] <- "parcel_id"
sc <- scenario("dbg", rulebook_example("auckland"), parcels = near[, "parcel_id"], roads = g$roads,
               zoning = g$zoning, layers = g$layers, water = g$water)
env <- suppressWarnings(build_envelopes(sc, keep_setbacks = TRUE, include_density = TRUE, variant_choice = "standard"))
print(env$stack[env$stack$site_id %in% ids, c("site_id", "variant", "storey", "ceiling_level", "clipped_area",
                                              "enabled_area", "binding")])
sb <- env$setbacks
seg <- sf::st_drop_geometry(prepare_sites(sc)$segments)
sb <- merge(sb[sb$site_id %in% ids & sb$storey == 1, ], seg[, c("segment_id", "boundary_class", "length", "tags",
                                                                  "adjacent_zone_key")], by = "segment_id")
print(sb[, c("site_id", "segment_id", "boundary_class", "length", "setback", "rule", "source", "adjacent_zone_key")])
res <- resolve_sites(prepare_sites(sc), sc$rulebook)
for (i in ids) {
  z <- res$params[[res$param_id[match(i, prepare_sites(sc)$sites$site_id)]]]
  cat("\n", i, ": height", unlist(z$height[c("value", "occupiable", "storeys")]), " ratios:",
      names(z$ratios), "\n")
}
