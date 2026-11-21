# Stage 6 gate, capacityengine side: the PC120 scenario on the gate tile.
#
# Run FROM THE capacityengine FOLDER, after export_ce_tile.R:
#   Rscript ../plancap/data-raw/gate/export_ce_pc120.R [tile_id] [scenario]
#
# Writes, in ../plancap/data-raw/cache (git-ignored):
#   * pc120_res_bundle.yaml: capacityengine's PC120 bundle with its
#     `extends:` merged (capacityengine's merge_plan_bundles()), for
#     data-raw/convert_capacityengine.R to convert (test-only rulebook);
#   * gate_<tile>_pc120.rds: the tile's PC120 sites (with each zone-split
#     piece's parent), the PC120 zoning, ground levels, and capacityengine's
#     results with terrain, surfaces and the measured front yard.

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
tile <- if (length(args)) args[1] else "t_011_011"
scen_name <- if (length(args) > 1) args[2] else "pc120_res"
scen <- scenario_config(scen_name, council = "auckland")
ctx <- region_context(scen)

b <- unclass(ctx$bundle)
attributes(b) <- list(names = names(b))
yaml::write_yaml(b, "../plancap/data-raw/cache/pc120_res_bundle.yaml")

sites <- read_region_tile(tile, "sites", cache_dir = scen$precomputed)
sites <- sites[!is.na(sites$zone_key), ]
bb <- sf::st_bbox(sites)
box <- function(pad) sf::st_as_sfc(sf::st_bbox(c(xmin = bb[["xmin"]] - pad, ymin = bb[["ymin"]] - pad,
                                                xmax = bb[["xmax"]] + pad, ymax = bb[["ymax"]] + pad),
                                              crs = sf::st_crs(sites)))
clip <- function(x, pad) {
  if (is.null(x) || !inherits(x, "sf") || !nrow(x)) return(x)
  x[lengths(sf::st_intersects(x, sf::st_transform(box(pad), sf::st_crs(x)))) > 0, ]
}
zf <- scen$zoning
zoning <- load_council_layer(zf$path, layer = zf$layer, key = zf$cache_key, cache_dir = "data/cache/region",
                             version_field = zf$version_field %||% "VERSIONSTATUS",
                             version_keep = unlist(zf$version_keep %||% 4)) |>
  apply_alias_map(ctx$bundle, label_field = zf$label_field %||% "ZONE")
zoning <- clip(zoning, 500)
zoning <- zoning[, c("zone_label", "zone_key")]
names(zoning)[1] <- "zone"

res <- suppressWarnings(run_region_tile(tile, ctx))

segs <- read_region_tile(tile, "segments", cache_dir = scen$precomputed, site_ids = sites$site_id)
mid <- sf::st_coordinates(sf::st_line_sample(sf::st_cast(sf::st_geometry(segs), "LINESTRING"), sample = 0.5))
ground <- list(
  sites = data.frame(site_id = sites$site_id, ground_mean = sites$ground_mean_m),
  segments = data.frame(site_id = segs$site_id, seq = as.integer(sub("^.*-s", "", segs$segment_id)),
                        x = mid[, 1], y = mid[, 2], ground = segs$ground_mean_m))
out <- list(tile = tile, scenario = scen_name,
            sites = sites[, intersect(c("site_id", "zone_key", "site_id_parent"), names(sites))],
            zoning = zoning, ground = ground, ce = res$sites, exported = Sys.time())
f <- file.path("../plancap/data-raw/cache", paste0("gate_", tile, "_pc120.rds"))
saveRDS(out, f)
cli::cli_inform("{scen_name} {tile}: {nrow(sites)} sites; {round(sum(res$sites$floorspace_m2))} m2, \\
                 {sum(res$sites$dwellings)} dwellings -> {f}")
