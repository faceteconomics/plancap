#' Scenarios: a rulebook with its maps and parcels
#'
#' A **scenario** is everything that determines capacity: a rulebook, the
#' parcels, roads and water, the zoning layer, and the layers the rulebook's
#' overlays and areas refer to. Comparing plan changes means comparing
#' scenarios, and two scenarios may differ in any of these.
#'
#' `scenario_change()` starts from an existing scenario and changes only what
#' it is given, which is how a plan change is usually described.
#'
#' @param name Name of the scenario.
#' @param rulebook A `plancap_rulebook`.
#' @param parcels Parcels (or sites) as `sf` polygons in a projected CRS.
#'   Road, rail and water parcels should be left out (supply roads
#'   separately).
#' @param zoning Zoning polygons with a column of zone codes (`zone_field`)
#'   that the rulebook's `zone_map` maps to zone keys.
#' @param roads Road parcels (polygons).
#' @param layers Named list of the other layers the rulebook refers to
#'   (overlays, areas, and layers named in distance conditions), named as the
#'   rulebook names them.
#' @param water Water features, for riparian, coastal and lakeside boundaries.
#' @param centrelines Road centrelines with a width column (`width_field`).
#' @param dem Optional ground surface as a `terra::SpatRaster`.
#' @param ground Optional ground levels supplied directly instead of a `dem`
#'   (from a survey, or another model): a list with `sites` (a data frame of
#'   `site_id` and `ground_mean`) and `segments` (a data frame of `site_id`,
#'   `seq`, the segment's position in its site's boundary counting from 1, and
#'   `ground`, the mean ground level along it). Give the segment's midpoint
#'   as `x` and `y` instead of `seq` to match segments by position.
#' @param easements Optional easement areas (rights of way), for the access
#'   width of rear sites ([find_access_widths()]).
#' @param other_parcels Optional parcels that are not sites (and not roads),
#'   among which jointly owned access lots are found.
#' @param buildings Optional building outlines, for yards set from the
#'   neighbours' existing setbacks ([find_existing_front_setbacks()]).
#' @param streets Optional named street centre lines for the same; default
#'   `centrelines`.
#' @param street_field Column of `streets` holding the street name.
#' @param neighbours Optional parcels beyond `parcels` that may be neighbours
#'   for a measured front yard (default `other_parcels`). Leave out parcels
#'   whose buildings are not dwellings, such as reserves and schools.
#' @param landholding Optional column of `parcels` naming the landholding
#'   each parcel belongs to, where parcels held together are still separate
#'   sites: pieces of one landholding share their best access width.
#' @param zone_field Column of `zoning` holding zone codes.
#' @param site_id Column of `parcels` to use as the site id. Default
#'   `"parcel_id"` if present, otherwise row numbers.
#' @param group_by Optional column of `parcels`: parcels sharing a value are
#'   one site (e.g. parcels held on one title).
#' @param width_field Column of `centrelines` holding road width (m).
#' @param morphology Named list of morphology settings for this scenario,
#'   overriding the rulebook's (see [morphology_defaults()]).
#' @param notes Free text.
#' @return A `plancap_scenario`.
#' @seealso [prepare_sites()]
#' @export
#' @examples
#' town <- exampleton()
#' base <- scenario("Operative", rulebook_example("exampleton"),
#'                  parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                  roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                  zoning = town$zoning,
#'                  layers = town[c("height_areas", "flood_hazard", "heritage",
#'                                  "trees", "precincts", "transit")],
#'                  water = town$water, centrelines = town$road_centrelines)
#' base
#' taller <- scenario_change(base, "MDR at 16 m",
#'   rulebook = set_rule(base$rulebook, "zones.MDR.height.value", 16))
scenario <- function(name, rulebook, parcels, zoning, roads = NULL, layers = list(),
                     water = NULL, centrelines = NULL, dem = NULL, ground = NULL,
                     easements = NULL, other_parcels = NULL, buildings = NULL, streets = NULL,
                     street_field = "name", neighbours = NULL, landholding = NULL, zone_field = "zone",
                     site_id = NULL, group_by = NULL, width_field = "width_m",
                     morphology = list(), notes = NULL) {
  check_string(name, null_ok = FALSE)
  check_rulebook(rulebook)
  for (a in c("parcels", "zoning")) {
    if (!inherits(get(a), "sf")) cli::cli_abort("{.arg {a}} must be an {.cls sf} layer.")
  }
  check_projected(parcels)
  if (!is.list(layers) || (length(layers) && is.null(names(layers)))) {
    cli::cli_abort("{.arg layers} must be a named list.")
  }
  site_id <- site_id %||% if ("parcel_id" %in% names(parcels)) "parcel_id"
  if (!is.null(site_id) && !site_id %in% names(parcels)) {
    cli::cli_abort("{.arg parcels} has no {.field {site_id}} column.")
  }
  if (!is.null(landholding) && !landholding %in% names(parcels)) {
    cli::cli_abort("{.arg parcels} has no {.field {landholding}} column.")
  }
  if (!is.null(group_by) && !group_by %in% names(parcels)) {
    cli::cli_abort("{.arg parcels} has no {.field {group_by}} column.")
  }
  if (!is.null(ground) && (!is.list(ground) || is.null(ground$sites) || is.null(ground$segments))) {
    cli::cli_abort("{.arg ground} must be a list with {.field sites} and {.field segments}.")
  }
  structure(list(name = name, rulebook = rulebook, parcels = parcels, zoning = zoning,
                 roads = roads, layers = layers, water = water, centrelines = centrelines,
                 dem = dem, ground = ground, easements = easements, other_parcels = other_parcels,
                 buildings = buildings, streets = streets, street_field = street_field,
                 neighbours = neighbours, landholding = landholding,
                 zone_field = zone_field, site_id = site_id, group_by = group_by,
                 width_field = width_field, morphology = morphology, notes = notes),
            class = "plancap_scenario")
}

#' @rdname scenario
#' @param base The scenario to start from.
#' @param ... For `scenario_change()`: any argument of `scenario()` to change.
#'   `layers` given here are merged into the base's layers by name (a layer set
#'   to `NULL` is removed).
#' @export
scenario_change <- function(base, name, ...) {
  if (!inherits(base, "plancap_scenario")) cli::cli_abort("{.arg base} must be a scenario.")
  ch <- list(...)
  bad <- setdiff(names(ch), setdiff(names(formals(scenario)), "name"))
  if (length(bad)) cli::cli_abort("Unknown scenario field{?s}: {.field {bad}}.")
  x <- unclass(base)
  if (!is.null(ch$layers)) {
    lay <- x$layers
    for (nm in names(ch$layers)) lay[nm] <- list(ch$layers[[nm]])
    ch$layers <- compact(lay)
  }
  x[names(ch)] <- ch
  x$name <- name
  x$changed_from <- base$name
  do.call(scenario, x[setdiff(names(x), "changed_from")]) |>
    (\(s) { s$changed_from <- base$name; s })()
}

#' @export
print.plancap_scenario <- function(x, ...) {
  cli::cli_text("{.strong <plancap scenario>} {x$name}",
                if (!is.null(x$changed_from)) " (changed from {x$changed_from})")
  cli::cli_text("Rulebook: {x$rulebook$plan$name}; {nrow(x$parcels)} parcels; \\
                 {nrow(x$zoning)} zoning features; layers: \\
                 {if (length(x$layers)) paste(names(x$layers), collapse = ', ') else 'none'}.")
  invisible(x)
}

#' Prepare sites for a scenario
#'
#' Turns a scenario's parcels and maps into sites ready for the engine, in two
#' steps whose results are kept and reused:
#'
#' 1. **Parcel geometry**, which depends only on parcels, roads, water, road
#'    centrelines and the ground surface: sites, boundary segments and their
#'    classes, frontages, corner, through and rear sites, access legs, road
#'    widths (see [morphology]).
#' 2. **Plan geometry**, which also depends on the zoning, overlay and area
#'    layers: sites split where zones cross them (only those sites are
#'    reclassified), the zone across each boundary, overlay and area
#'    membership, and distances to features rules refer to.
#'
#' Each step is stored under a hash of its inputs. A second scenario with the
#' same parcels reuses step 1; one that changes only rule values reuses both.
#' Nothing here depends on rule values, so a rule-only change costs nothing.
#'
#' @param x A [scenario()].
#' @param cache Whether to reuse and store prepared steps (in memory, for the
#'   session).
#' @return A `plancap_sites` object: a list with `sites` (one row per site,
#'   `sf`), `segments` (one row per boundary segment, `sf`), `access_legs`,
#'   `overlays` and `areas` (site membership, with the share of each site
#'   covered), `distances`, a `report` of anything that could not be done,
#'   and the `hashes` of its inputs.
#' @export
#' @examples
#' town <- exampleton()
#' base <- scenario("Operative", rulebook_example("exampleton"),
#'                  parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                  roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                  zoning = town$zoning, layers = town[c("height_areas", "precincts")])
#' s <- prepare_sites(base)
#' s
#' table(s$segments$boundary_class)
prepare_sites <- function(x, cache = TRUE) {
  if (!inherits(x, "plancap_scenario")) cli::cli_abort("{.arg x} must be a {.fn scenario}.")
  m <- morphology_settings(x$rulebook, x$morphology)
  h_parcels <- rlang::hash(list(
    parcels = x$parcels, roads = x$roads, water = x$water, centrelines = x$centrelines,
    dem = dem_signature(x$dem), ground = x$ground, easements = x$easements,
    other_parcels = x$other_parcels, landholding = x$landholding, site_id = x$site_id, group_by = x$group_by,
    width_field = x$width_field, morphology = m, version = utils::packageVersion("plancap")))
  rb <- x$rulebook
  plan_rules <- list(zone_map = rb$zone_map, zone_families = rb$zone_families,
                     overlays = lapply(rb$overlays, `[`, c("layer", "filter", "buffer",
                                                           "value_field", "value_map", "value")),
                     areas = lapply(rb$areas, `[`, c("layer", "filter", "sub_area_field")),
                     distance_layers = sort(unique(unlist(lapply(c(rb$zones, rb$bonuses, rb$entitlements),
                                                                 find_key, key = "distance_to")))))
  h_plan <- rlang::hash(list(h_parcels, zoning = x$zoning, zone_field = x$zone_field,
                             layers = x$layers, rules = plan_rules))

  reused <- c(parcel_geometry = FALSE, plan_geometry = FALSE)
  plan <- if (cache) cache_get(h_plan) else NULL
  if (!is.null(plan)) {
    reused[] <- TRUE
  } else {
    pg <- if (cache) cache_get(h_parcels) else NULL
    if (!is.null(pg)) {
      reused["parcel_geometry"] <- TRUE
    } else {
      sites <- make_sites(x$parcels, x$site_id, x$group_by, x$landholding)
      pg <- parcel_geometry(sites, roads = x$roads, water = x$water,
                            centrelines = x$centrelines, width_field = x$width_field,
                            rulebook = x$rulebook, morphology = x$morphology,
                            easements = x$easements, other_parcels = x$other_parcels)
      if (!is.null(x$dem)) pg <- attach_terrain(pg, x$dem)
      if (!is.null(x$ground)) pg <- attach_ground(pg, x$ground)
      if (cache) cache_set(h_parcels, pg)
    }
    plan <- plan_geometry(pg, x$zoning, x$rulebook, layers = x$layers,
                          zone_field = x$zone_field,
                          inputs = list(roads = x$roads, water = x$water, dem = x$dem, ground = x$ground,
                                        easements = x$easements, other_parcels = x$other_parcels,
                                        centrelines = x$centrelines, width_field = x$width_field),
                          morphology = x$morphology)
    if (cache) cache_set(h_plan, plan)
  }
  structure(c(plan, list(scenario = x$name, morphology = m, water = x$water,
                         hashes = c(parcel_geometry = h_parcels, plan_geometry = h_plan),
                         reused = reused)),
            class = "plancap_sites")
}

#' @export
print.plancap_sites <- function(x, ...) {
  s <- x$sites
  cli::cli_text("{.strong <plancap sites>} {x$scenario}: {nrow(s)} site{?s}, \\
                 {nrow(x$segments)} boundary segments.")
  zt <- sort(table(s$zone_key, useNA = "ifany"), decreasing = TRUE)
  names(zt)[is.na(names(zt))] <- "(none)"
  cli::cli_text("Zones: {paste0(names(zt), ' ', zt, collapse = ', ')}.")
  cli::cli_text("Corner {sum(s$is_corner)}, through {sum(s$is_through)}, rear {sum(s$is_rear)} \\
                 ({sum(s$access_leg_area > 0)} with access legs); split by zone \\
                 {x$report$sites_split %||% 0}.")
  if (any(x$reused)) cli::cli_text("{.emph Reused: {names(x$reused)[x$reused]}.}")
  rep <- x$report[setdiff(names(x$report), c("sites_split"))]
  rep <- rep[vapply(rep, function(v) length(v) && !identical(v, 0L) && !identical(v, 0), logical(1))]
  for (nm in names(rep)) cli::cli_alert_warning("{nm}: {paste(rep[[nm]], collapse = ', ')}")
  invisible(x)
}

# Sites from parcels: one per parcel, or parcels dissolved by a grouping column.
make_sites <- function(parcels, site_id = NULL, group_by = NULL, landholding = NULL) {
  ids <- if (!is.null(site_id)) as.character(parcels[[site_id]]) else
    sprintf("P%06d", seq_len(nrow(parcels)))
  if (anyDuplicated(ids)) cli::cli_abort("Site ids must be unique; {.field {site_id}} has duplicates.")
  if (is.null(group_by)) {
    out <- sf::st_sf(site_id = ids, geometry = sf::st_geometry(parcels))
    out$parcel_ids <- as.list(ids)
    if (!is.null(landholding)) out$landholding <- as.character(parcels[[landholding]])
    return(out)
  }
  grp <- as.character(parcels[[group_by]])
  grp[is.na(grp)] <- ids[is.na(grp)]
  u <- unique(grp)
  g <- as_geos(parcels)
  fid <- match(grp, u)
  o <- order(fid)
  geom <- geos::geos_unary_union(geos::geos_make_collection(g[o], feature_id = fid[o]))
  first_id <- ids[match(u, grp)]
  out <- sf::st_sf(site_id = first_id, geometry = sf::st_as_sfc(geom))
  sf::st_crs(out) <- sf::st_crs(parcels)
  out$parcel_ids <- split(ids, factor(fid, levels = seq_along(u)))
  names(out$parcel_ids) <- NULL
  if (!is.null(landholding)) out$landholding <- as.character(parcels[[landholding]])[match(u, grp)]
  out
}

dem_signature <- function(dem) {
  if (is.null(dem)) return(NULL)
  if (!inherits(dem, "SpatRaster")) cli::cli_abort("{.arg dem} must be a {.cls SpatRaster}.")
  list(terra::sources(dem), as.vector(terra::ext(dem)), dim(dem), terra::crs(dem))
}

# Ground level at each boundary segment's midpoint and the site's mean ground
# level and slope, from a DEM.
attach_terrain <- function(pg, dem) {
  rlang::check_installed("terra", reason = "to read a ground surface.")
  seg <- pg$segments
  # Mean ground along each boundary segment: sampled every metre, ends included.
  len <- sqrt((seg$x1 - seg$x0)^2 + (seg$y1 - seg$y0)^2)
  k <- pmax(2L, ceiling(len) + 1L)
  id <- rep(seq_len(nrow(seg)), k)
  t <- unlist(lapply(k, function(m) seq(0, 1, length.out = m)))
  pts <- cbind(seg$x0[id] + t * (seg$x1[id] - seg$x0[id]), seg$y0[id] + t * (seg$y1[id] - seg$y0[id]))
  z <- terra::extract(dem, pts)[, 1]
  seg$ground <- as.vector(tapply(z, id, mean, na.rm = TRUE))
  seg$ground[is.nan(seg$ground)] <- NA
  v <- terra::vect(pg$sites)
  pg$sites$ground_mean <- terra::extract(dem, v, fun = mean, na.rm = TRUE)[, 2]
  slope <- terra::terrain(dem, "slope", unit = "degrees")
  pg$sites$slope <- tan(terra::extract(slope, v, fun = mean, na.rm = TRUE)[, 2] * pi / 180) * 100
  pg$segments <- seg
  pg
}

# Ground levels supplied as tables rather than sampled from a DEM.
attach_ground <- function(pg, ground) {
  seg <- pg$segments
  seq_of <- as.integer(sub("^.*-", "", seg$segment_id))
  key <- paste(seg$site_id, seq_of)
  g <- ground$segments
  if (all(c("x", "y") %in% names(g))) {
    # By position: each segment takes the ground of the nearest supplied
    # midpoint of its own site, wherever its boundary is taken to start.
    mx <- (seg$x0 + seg$x1) / 2
    my <- (seg$y0 + seg$y1) / 2
    by_site <- split(seq_len(nrow(g)), g$site_id)
    seg$ground <- vapply(seq_len(nrow(seg)), function(i) {
      k <- by_site[[seg$site_id[i]]]
      if (is.null(k)) return(NA_real_)
      g$ground[k[which.min((g$x[k] - mx[i])^2 + (g$y[k] - my[i])^2)]]
    }, 0)
  } else {
    seg$ground <- g$ground[match(key, paste(g$site_id, g$seq))]
  }
  pg$sites$ground_mean <- ground$sites$ground_mean[match(pg$sites$site_id, ground$sites$site_id)]
  pg$segments <- seg
  pg
}

# ---- Session cache --------------------------------------------------------------

cache_get <- function(key) the$cache[[key]]

cache_set <- function(key, value, max_items = 20L) {
  if (is.null(the$cache)) the$cache <- list()
  the$cache[[key]] <- value
  if (length(the$cache) > max_items) the$cache <- utils::tail(the$cache, max_items)
  invisible(value)
}

#' Clear plancap's cache of prepared sites
#'
#' @return `NULL`, invisibly.
#' @export
#' @examples
#' clear_site_cache()
clear_site_cache <- function() {
  the$cache <- list()
  invisible(NULL)
}
