# Stage 4 gate, capacityengine side: export one region tile's inputs and
# capacityengine's results for it, so plancap can be run on identical inputs.
#
# Run FROM THE capacityengine FOLDER (its renv library):
#   Rscript ../plancap/data-raw/gate/export_ce_tile.R [tile_id]
#
# Writes ../plancap/data-raw/cache/gate_<tile>.rds (git-ignored: it holds
# LINZ and Auckland Council data). Results are exported twice:
#   * `ce_flat`: run_region_tile() with the ground datum switched off, so the
#     comparison isolates everything but terrain;
#   * `ce_published`: the tile's rows of outputs/region_sites.parquet.

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
scen <- scenario_config("operative", council = "auckland")
ctx <- region_context(scen)

published <- arrow::read_parquet("outputs/region_sites.parquet")
if (length(args)) {
  tile <- args[1]
} else {
  # A mixed suburban tile: many sites, several zones, a precinct.
  tb <- table(published$tile_id)
  t <- data.frame(tile_id = names(tb), n = as.vector(tb), stringsAsFactors = FALSE)
  nz <- tapply(published$zone_key, published$tile_id, function(z) length(unique(z)))
  np <- tapply(!is.na(published$precinct), published$tile_id, sum)
  t$zones <- nz[t$tile_id]
  t$precinct_sites <- np[t$tile_id]
  t <- t[t$n >= 1500 & t$n <= 3500 & t$zones >= 6 & t$precinct_sites > 0, ]
  tile <- t$tile_id[order(-t$zones, -t$n)][1]
}
cli::cli_inform("tile {tile}")

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

roads <- clip(sf::st_read("data/cache/region/linz_road_parcels.gpkg", quiet = TRUE), 80)
zf <- scen$zoning
zoning <- load_council_layer(zf$path, layer = zf$layer, key = zf$cache_key, cache_dir = "data/cache/region",
                             version_field = zf$version_field %||% "VERSIONSTATUS",
                             version_keep = unlist(zf$version_keep %||% 4)) |>
  apply_alias_map(ctx$bundle, label_field = zf$label_field %||% "ZONE")
zoning <- clip(zoning, 500)
zoning <- zoning[, c("zone_label", "zone_key")]
names(zoning)[1] <- "zone"

# Overlay layers, keyed by the layer name the converted rulebook uses
# (capacityengine's source_layer, or surface_raster for surfaces).
layers <- list()
for (id in names(ctx$layers)) {
  def <- ctx$bundle$overlays[[id]]
  nm <- def$surface_raster %||% def$source_layer
  layers[[nm]] <- clip(ctx$layers[[id]], 50)
}
norm <- function(x) gsub("^_|_$", "", gsub("[^a-z0-9]+", "_", tolower(x)))
if (!is.null(ctx$precincts)) {
  pr <- clip(ctx$precincts, 50)
  if ("VERSIONSTATUS" %in% names(pr)) pr <- pr[as.character(pr$VERSIONSTATUS) %in% "4", ]
  # capacityengine's intersect_precincts(): the name carries the sub-precinct
  # ("Devonport Peninsula sub-precinct E"); first line only; no [rcp/dp].
  nm <- sub("[\r\n].*$", "", as.character(pr$PRECINCT_NAME))
  nm <- trimws(gsub("\\s*\\[[^]]*\\]", "", nm, perl = TRUE))
  is_sub <- grepl("sub[- ]precinct", nm, ignore.case = TRUE)
  base <- trimws(sub("(?i)\\s+sub[- ]precinct\\s+.*$", "", nm, perl = TRUE))
  pr$precinct_key <- norm(base)
  pr$sub_precinct <- ifelse(is_sub, toupper(trimws(sub("(?i)^.*sub[- ]precinct\\s+", "", nm, perl = TRUE))),
                            NA_character_)
  layers[["precincts"]] <- pr
}
# capacityengine holds water as geos geometry by yard class; plancap wants one
# layer with a type. The "setback" class has no plancap equivalent yet.
water <- NULL
if (!is.null(ctx$water)) {
  type_of <- c(coastal = "coast", riparian = "river", lakeside = "lake", setback = "setback")
  water <- do.call(rbind, lapply(names(ctx$water), function(k) {
    g <- sf::st_as_sfc(ctx$water[[k]]$geom)
    sf::st_crs(g) <- sf::st_crs(sites)
    sf::st_sf(type = type_of[[k]], geometry = g)
  }))
  water <- clip(water, 150)
}

# capacityengine on flat ground: the cached datum switched off for this run.
ns <- asNamespace("capacityengine")
real_datum <- get("cached_datum", envir = ns)
unlockBinding("cached_datum", ns)
assign("cached_datum", function(...) NULL, envir = ns)
flat <- suppressWarnings(run_region_tile(tile, ctx))
# And without the special character front yard measured from the neighbours'
# existing houses (value_from), which plancap does not carry yet.
real_front <- get("needs_existing_front_setbacks", envir = ns)
unlockBinding("needs_existing_front_setbacks", ns)
assign("needs_existing_front_setbacks", function(...) character(0), envir = ns)
flat_nofront <- suppressWarnings(run_region_tile(tile, ctx))
assign("cached_datum", real_datum, envir = ns)
# Terrain on, front yard still off: plancap's like-for-like with terrain.
terrain_nofront <- suppressWarnings(run_region_tile(tile, ctx))
assign("needs_existing_front_setbacks", real_front, envir = ns)
# Terrain on and the front yard on: everything (the published run's settings).
terrain <- suppressWarnings(run_region_tile(tile, ctx))

# Ground levels from the tile cache, for plancap's `ground` argument: the
# mean ground along each boundary segment and over each site.
segs <- read_region_tile(tile, "segments", cache_dir = scen$precomputed, site_ids = sites$site_id)
mid <- sf::st_coordinates(sf::st_line_sample(sf::st_cast(sf::st_geometry(segs), "LINESTRING"), sample = 0.5))
ground <- list(
  sites = data.frame(site_id = sites$site_id, ground_mean = sites$ground_mean_m),
  segments = data.frame(site_id = segs$site_id,
                        seq = as.integer(sub("^.*-s", "", segs$segment_id)),
                        x = mid[, 1], y = mid[, 2],
                        ground = segs$ground_mean_m))
# Context for rear-site access (item 259) and the special character front
# yard measured from the neighbours' houses (item 314), within 150 m: easement
# areas, the other primary parcels (access lots and neighbours), building
# outlines and named road sections. Read as capacityengine's region run does.
halo_wkt <- sf::st_as_text(box(150))
rd <- function(f) sf::st_read(file.path("data/cache/region", f), wkt_filter = halo_wkt, quiet = TRUE)
ease <- rd("linz_non_primary_parcels.gpkg")
ease <- ease[ease$parcel_intent == "Easement", 0]
prim <- rd("linz_primary_parcels.gpkg")
prim <- prim[!prim$parcel_intent %in% c("Road", "Railway", "Hydro"), 0]
buildings <- rd("linz_building_outlines.gpkg")[, 0]
# The front yard's neighbours, as capacityengine's region_tile() takes them:
# the region's sites within 150 m of the tile.
idx <- ctx$idx
tb <- idx[idx$tile_id == tile, , drop = FALSE]
near <- idx$tile_id[idx$xmax >= tb$xmin - 150 & idx$xmin <= tb$xmax + 150 &
                      idx$ymax >= tb$ymin - 150 & idx$ymin <= tb$ymax + 150]
nb <- do.call(rbind, lapply(setdiff(near, tile), function(t)
  read_region_tile(t, "sites", cache_dir = scen$precomputed)[, "site_id"]))
nb <- if (is.null(nb)) NULL else nb[lengths(sf::st_intersects(nb, box(150))) > 0, 0]
streets <- rd("linz_road_sections.gpkg")[, "full_road_name"]
out <- list(tile = tile, sites = sites[, intersect(c("site_id", "zone_key", "site_id_parent"), names(sites))],
            neighbours = nb, ground = ground, roads = roads[, 0], zoning = zoning,
            easements = ease, other_parcels = prim, buildings = buildings, streets = streets,
            layers = layers, water = water, ce_flat = flat$sites, ce_flat_nofront = flat_nofront$sites,
            ce_terrain_nofront = terrain_nofront$sites, ce_terrain = terrain$sites,
            ce_published = as.data.frame(published[published$tile_id == tile, ]),
            exported = Sys.time())
dir.create("../plancap/data-raw/cache", showWarnings = FALSE)
# Height surfaces (rasters of absolute elevation), cropped to the tile and
# written beside the export; terra objects do not survive saveRDS().
surface_files <- character()
for (nm in names(ctx$surfaces)) {
  r <- ctx$surfaces[[nm]]
  bx <- sf::st_transform(box(100), terra::crs(r))
  rc <- tryCatch(terra::crop(r, terra::ext(terra::vect(bx))), error = function(e) NULL)
  if (is.null(rc) || all(is.na(terra::values(rc)))) next
  f <- file.path("../plancap/data-raw/cache", paste0("gate_", tile, "_surface_", nm, ".tif"))
  terra::writeRaster(rc, f, overwrite = TRUE)
  # Keyed by the raster name the converted rulebook's overlay uses
  # (capacityengine keys its surfaces by overlay id).
  surface_files[[ctx$bundle$overlays[[nm]]$surface_raster %||% nm]] <- basename(f)
}
out$surface_files <- surface_files
f <- file.path("../plancap/data-raw/cache", paste0("gate_", tile, ".rds"))
saveRDS(out, f)
cli::cli_inform("{nrow(sites)} sites, {nrow(roads)} roads, {nrow(zoning)} zoning features, \\
                 {length(layers)} layers -> {f}")
cli::cli_inform("flat: {round(sum(flat$sites$floorspace_m2))} m2, {sum(flat$sites$dwellings)} dwellings; \\
                 published: {round(sum(out$ce_published$floorspace_m2))} m2, {sum(out$ce_published$dwellings)} dwellings")
