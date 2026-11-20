# Gate debugging, capacityengine side: per-storey envelope and setbacks for a
# few sites of the exported tile, flat ground. Run from the capacityengine folder:
#   Rscript ../plancap/data-raw/gate/debug_sites_ce.R t_011_011 S051662 S191701
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
a <- commandArgs(trailingOnly = TRUE)
tile <- a[1]
ids <- a[-1]
scen <- scenario_config("operative", council = "auckland")
ctx <- region_context(scen)
sites <- read_region_tile(tile, "sites", cache_dir = scen$precomputed)
sites <- sites[sites$site_id %in% ids, ]
segs <- read_region_tile(tile, "segments", cache_dir = scen$precomputed, site_ids = sites$site_id)
segs <- add_overlay_adjacency(segs, ctx$layers, ctx$bundle)
ov <- suppressWarnings(intersect_overlays(sites, ctx$layers, ctx$bundle))
prec <- if (is.null(ctx$precincts)) NULL else intersect_precincts(sites, ctx$precincts, ctx$bundle)
zp <- resolve_zone_parameters(ctx$bundle, overlay_stacks = ov$stacks, use_precincts = !is.null(ctx$precincts))
sites$stack_id <- ov$site_stack$stack_id[match(sites$site_id, ov$site_stack$site_id)]
sites$param_id <- site_param_ids(sites, prec, zp)
h <- suppressWarnings(resolve_effective_height(sites, zp, overlay_values = ov$membership))
print(sf::st_drop_geometry(h)[, intersect(c("site_id", "zone_key", "param_id", "height_total_m",
                                             "height_occupiable_m", "storeys_nominal", "storey_height_m",
                                             "site_area_m2"), names(h))])
terrain <- Sys.getenv("TERRAIN") == "1"
datum <- if (terrain) cached_datum(sites, segs)
env <- suppressWarnings(build_envelope(h, segs, zp, include_density = TRUE, keep_setbacks = TRUE,
                                       segment_datum = datum$segments, site_datum = datum$sites,
                                       water = water_near(ctx$water, h, pad_m = 100)))
print(as.data.frame(env)[, c("site_id", "storey", "ceiling_level_m", "clipped_area_m2")])
sb <- attr(env, "setbacks")
print(as.data.frame(sb)[sb$storey == 3, intersect(c("site_id", "segment_id", "boundary_class", "length_m",
                                                    "setback_m", "ground_offset_m", "rule"), names(sb))])
cp <- apply_caps(env, zp)
print(as.data.frame(cp)[, c("site_id", "storey", "enabled_area_m2", "binding_constraint")])
fin <- enforce_stack_rules(cp, min_floorplate_m2 = ctx$bundle$defaults$min_floorplate_m2, zone_parameters = zp)
print(as.data.frame(fin)[, intersect(c("site_id", "storey", "enabled_area_m2", "binding_constraint"), names(fin))])
k <- match(unique(h$param_id), zp$param_id)
keep <- c("param_id", "height_total_m", "storey_height_m", "far_max", "max_floorplate_m2", "max_site_floorspace_m2",
          "coverage_max", "landscaping_min")
print(as.data.frame(zp)[k, intersect(keep, names(zp))])
cat("\nLI zone height in bundle:\n"); str(ctx$bundle$zones$BUS_LIGHT_INDUSTRY$height)
cat("\ncodes 27/32:\n"); cc <- read.csv("inst/extdata/aup_zone_concordance.csv"); print(cc[cc[[1]] %in% c(27, 32) | cc[[2]] %in% c(27, 32), ])
