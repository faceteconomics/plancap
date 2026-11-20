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
assign("needs_existing_front_setbacks", real_front, envir = ns)
assign("cached_datum", real_datum, envir = ns)

out <- list(tile = tile, sites = sites[, c("site_id", "zone_key")], roads = roads[, 0], zoning = zoning,
            layers = layers, water = water, ce_flat = flat$sites, ce_flat_nofront = flat_nofront$sites,
            ce_published = as.data.frame(published[published$tile_id == tile, ]),
            exported = Sys.time())
dir.create("../plancap/data-raw/cache", showWarnings = FALSE)
f <- file.path("../plancap/data-raw/cache", paste0("gate_", tile, ".rds"))
saveRDS(out, f)
cli::cli_inform("{nrow(sites)} sites, {nrow(roads)} roads, {nrow(zoning)} zoning features, \\
                 {length(layers)} layers -> {f}")
cli::cli_inform("flat: {round(sum(flat$sites$floorspace_m2))} m2, {sum(flat$sites$dwellings)} dwellings; \\
                 published: {round(sum(out$ce_published$floorspace_m2))} m2, {sum(out$ce_published$dwellings)} dwellings")
