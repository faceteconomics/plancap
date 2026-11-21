#' Define a zone
#'
#' A zone holds every rule that applies to sites in it. `zone()` defines a full
#' zone for [add_zone()]; `zone_changes()` takes the same arguments, all
#' optional, and describes only what a precinct, overlay or scenario changes.
#'
#' Lengths are in the rulebook's units (metres unless the rulebook says feet).
#'
#' @param key Short identifier, used everywhere else in the rulebook.
#' @param label Human-readable name.
#' @param method How capacity is estimated: `"volumetric"` (build the storey
#'   envelope), `"density"` (read dwellings straight off a density rule),
#'   `"hybrid"` (both; the lesser wins) or `"none"` (the zone carries no
#'   capacity but is kept so rules that depend on neighbouring zones can see
#'   it, e.g. open space).
#' @param height A [height_limit()].
#' @param setbacks A list of setbacks from [yard()], [plane()],
#'   [upper_level_setback()], [proportional_setback()] or [setback_profile()].
#' @param coverage,landscaping,impervious,paved,far,deep_soil Site ratio rules:
#'   maximum building coverage, minimum landscaped area, maximum impervious
#'   area, maximum paved area, maximum floor area ratio, minimum deep soil.
#'   Each a number, a formula string or a [ratio()].
#' @param form Building form limits, from [building_form()].
#' @param density Density rules, from [density()].
#' @param use Uses enabled and the residential share, from [use_mix()].
#' @param storey_height,ground_floor_height Storey heights (m). Default from
#'   the rulebook defaults.
#' @param variants Named list describing alternative standards; each element
#'   a list with `label` and `source`. Rules are tied to a variant with their
#'   own `variant` argument.
#' @param source Citation for the zone.
#' @param notes Free text.
#' @return A list with class `plancap_zone`.
#' @seealso [add_zone()]
#' @export
#' @examples
#' zone("MRZ", "Medium Density Residential",
#'   height = height_limit(11, roof_allowance = 1, storeys = 3, source = "MRZ-S1"),
#'   setbacks = list(
#'     yard(1.5, "road", source = "MRZ-S4"),
#'     yard(1, c("side", "rear"), source = "MRZ-S4"),
#'     plane(60, start_height = 4, boundaries = c("side", "rear"), source = "MRZ-S3")
#'   ),
#'   coverage = ratio(0.5, source = "MRZ-S5"),
#'   landscaping = ratio(0.2, source = "MRZ-S6"))
zone <- function(key, label = NULL, method = c("volumetric", "density", "hybrid", "none"),
                 height = NULL, setbacks = list(), coverage = NULL, landscaping = NULL,
                 impervious = NULL, paved = NULL, far = NULL, deep_soil = NULL,
                 form = NULL, density = NULL, use = NULL, storey_height = NULL,
                 ground_floor_height = NULL, variants = NULL, source = NULL,
                 notes = NULL) {
  check_string(key, null_ok = FALSE)
  method <- rlang::arg_match(method)
  z <- build_zone(label = label, method = method, height = height, setbacks = setbacks,
                  coverage = coverage, landscaping = landscaping, impervious = impervious,
                  paved = paved, far = far, deep_soil = deep_soil, form = form,
                  density = density, use = use, storey_height = storey_height,
                  ground_floor_height = ground_floor_height, variants = variants,
                  source = source, notes = notes)
  attr(z, "key") <- key
  class(z) <- "plancap_zone"
  z
}

#' @rdname zone
#' @param ... For `zone_changes()`: any arguments of `zone()` except `key`,
#'   plus `replaces_setbacks`: the setback kinds (`"yard"`, `"plane"`,
#'   `"upper_level"`, `"proportional"`, `"profile"`) whose rules the change's
#'   `setbacks` replace. The zone's setbacks of other kinds are kept. Defaults
#'   to the kinds that appear in the change's `setbacks`; give it with an empty
#'   `setbacks` list to remove every rule of a kind (e.g. a precinct with no
#'   recession plane).
#' @export
zone_changes <- function(...) {
  args <- list(...)
  if ("key" %in% names(args)) cli::cli_abort("{.fn zone_changes} takes no {.arg key}.")
  if (!is.null(args$method)) check_choice(args$method, c("volumetric", "density", "hybrid", "none"))
  kinds <- c("yard", "plane", "upper_level", "proportional", "profile")
  rs <- args$replaces_setbacks
  args$replaces_setbacks <- NULL
  if (!is.null(rs) && (!is.character(rs) || length(setdiff(rs, kinds)))) {
    cli::cli_abort("{.arg replaces_setbacks} must be among {.val {kinds}}.")
  }
  z <- do.call(build_zone, args)
  if (!is.null(args$setbacks)) {
    rs <- rs %||% unique(vapply(z$setbacks %||% list(), `[[`, "", "kind"))
  }
  if (length(rs)) z$replaces_setbacks <- rs
  structure(z, class = "plancap_zone_changes")
}

build_zone <- function(label = NULL, method = NULL, height = NULL, setbacks = NULL,
                       coverage = NULL, landscaping = NULL, impervious = NULL,
                       paved = NULL, far = NULL, deep_soil = NULL, form = NULL,
                       density = NULL, use = NULL, storey_height = NULL,
                       ground_floor_height = NULL, variants = NULL, source = NULL,
                       notes = NULL, call = rlang::caller_env()) {
  check_string(label, call = call)
  check_string(source, call = call)
  check_string(notes, call = call)
  check_number(storey_height, lower = 0, call = call)
  check_number(ground_floor_height, lower = 0, call = call)
  if (!is.null(height) && !inherits(height, "plancap_height")) {
    cli::cli_abort("{.arg height} must come from {.fn height_limit}.", call = call)
  }
  if (!is.null(setbacks)) {
    if (inherits(setbacks, "plancap_setback")) setbacks <- list(setbacks)
    ok <- vapply(setbacks, inherits, logical(1), "plancap_setback")
    if (!all(ok)) cli::cli_abort("Every element of {.arg setbacks} must be a setback rule.", call = call)
    setbacks <- lapply(setbacks, unclass)
  }
  as_ratio <- function(x, nm) {
    if (is.null(x)) return(NULL)
    if (inherits(x, "plancap_ratio")) return(unclass(x))
    if (inherits(x, "plancap_bands")) return(list(bands = unclass(x)))
    check_value(x, arg = nm, call = call)
    list(value = x)
  }
  ratios <- compact(list(
    coverage_max = as_ratio(coverage, "coverage"),
    landscaping_min = as_ratio(landscaping, "landscaping"),
    impervious_max = as_ratio(impervious, "impervious"),
    paved_max = as_ratio(paved, "paved"),
    far_max = as_ratio(far, "far"),
    deep_soil_min = as_ratio(deep_soil, "deep_soil")
  ))
  for (part in c("form", "density", "use")) {
    v <- get(part)
    cls <- paste0("plancap_", part)
    if (!is.null(v) && !inherits(v, cls)) {
      fn <- c(form = "building_form", density = "density", use = "use_mix")[[part]]
      cli::cli_abort("{.arg {part}} must come from {.fn {fn}}.", call = call)
    }
  }
  compact(list(
    label = label, method = method, source = source, notes = notes,
    height = if (!is.null(height)) unclass(height),
    storey_height = storey_height, ground_floor_height = ground_floor_height,
    setbacks = if (length(setbacks)) setbacks else NULL,
    ratios = if (length(ratios)) ratios else NULL,
    form = if (!is.null(form)) unclass(form),
    density = if (!is.null(density)) unclass(density),
    use = if (!is.null(use)) unclass(use),
    variants = variants
  ))
}

#' Height limit
#'
#' @param value Maximum height (m) above the datum, including any roof
#'   allowance.
#' @param occupiable Height (m) up to which floors may be built. Defaults to
#'   `value - roof_allowance`.
#' @param roof_allowance Extra height (m) allowed for a roof form only, which
#'   yields no floor space.
#' @param storeys The storey count the plan intends; storey height is taken as
#'   `occupiable / storeys` where given.
#' @param from_overlay Name of an overlay that supplies the height where the
#'   zone states none (e.g. a height control map).
#' @param datum What height is measured from: `"ground"` (existing ground,
#'   the default), `"finished"`, `"average"` (average ground level), `"road"`
#'   or `"sea_level"` (an absolute level).
#' @param no_limit `TRUE` if the plan sets no height limit; the rulebook's
#'   `no_limit_height` stand-in is used and results are flagged.
#' @param source Citation.
#' @return A list with class `plancap_height`.
#' @export
#' @examples
#' height_limit(12, occupiable = 11, storeys = 3, source = "MRZ-S2")
#' height_limit(from_overlay = "height_control", source = "MCZ-S1")
height_limit <- function(value = NULL, occupiable = NULL, roof_allowance = NULL,
                         storeys = NULL, from_overlay = NULL, datum = "ground",
                         no_limit = FALSE, source = NULL) {
  check_value(value)
  check_number(occupiable, lower = 0)
  check_number(roof_allowance, lower = 0)
  check_number(storeys, lower = 1)
  check_string(from_overlay)
  check_choice(datum, c("ground", "finished", "average", "road", "sea_level"))
  check_flag(no_limit)
  if (is.null(value) && is.null(from_overlay) && !no_limit) {
    cli::cli_abort("Give {.arg value}, {.arg from_overlay} or {.code no_limit = TRUE}.")
  }
  if (is.null(occupiable) && !is.null(roof_allowance) && is.numeric(value)) {
    occupiable <- value - roof_allowance
  }
  structure(compact(list(
    value = value, occupiable = occupiable, roof_allowance = roof_allowance,
    storeys = storeys, from_overlay = from_overlay,
    datum = if (datum != "ground") datum else NULL,
    no_limit = if (no_limit) TRUE else NULL, source = source
  )), class = "plancap_height")
}

#' Building form limits
#'
#' Limits on the shape and size of buildings that are not setbacks or site
#' ratios. Areas in m2, lengths in m.
#'
#' @param max_floorplate Maximum floor area of any storey.
#' @param min_floorplate Smallest storey worth building; smaller storeys end
#'   the stack. Default from the rulebook defaults.
#' @param max_tower_floorplate,tower_above_height,tower_above_storey Tower
#'   floorplate limit and where the tower starts.
#' @param max_tower_dimension Maximum plan dimension of a tower.
#' @param tower_separation Minimum distance between towers.
#' @param max_building_length Maximum length of a building elevation.
#' @param building_separation Minimum distance between buildings on a site: a
#'   number or [bands()] by height.
#' @param max_building_depth Maximum building depth (e.g. 18 m for apartments).
#' @param min_building_width Minimum building width.
#' @param site_shape A length-2 vector `c(width, depth)`: a rectangle that must
#'   fit on the site for it to be developable.
#' @param max_site_floorspace Maximum floor area on one site.
#' @param source Citation.
#' @return A list with class `plancap_form`.
#' @export
#' @examples
#' building_form(max_building_length = 20, building_separation = 10,
#'               source = "HRZ-S15, HRZ-S16")
building_form <- function(max_floorplate = NULL, min_floorplate = NULL,
                          max_tower_floorplate = NULL, tower_above_height = NULL,
                          tower_above_storey = NULL, max_tower_dimension = NULL,
                          tower_separation = NULL, max_building_length = NULL,
                          building_separation = NULL, max_building_depth = NULL,
                          min_building_width = NULL, site_shape = NULL,
                          max_site_floorspace = NULL, source = NULL) {
  for (a in c("max_floorplate", "min_floorplate", "max_tower_floorplate",
              "tower_above_height", "max_tower_dimension", "tower_separation",
              "max_building_length", "max_building_depth", "min_building_width",
              "max_site_floorspace")) {
    check_number(get(a), arg = a, lower = 0)
  }
  check_number(tower_above_storey, lower = 1)
  if (inherits(building_separation, "plancap_bands")) {
    building_separation <- list(bands = unclass(building_separation))
  } else {
    check_number(building_separation, lower = 0)
  }
  if (!is.null(site_shape) && (!is.numeric(site_shape) || length(site_shape) != 2)) {
    cli::cli_abort("{.arg site_shape} must be {.code c(width, depth)}.")
  }
  structure(compact(list(
    max_floorplate = max_floorplate, min_floorplate = min_floorplate,
    max_tower_floorplate = max_tower_floorplate, tower_above_height = tower_above_height,
    tower_above_storey = tower_above_storey, max_tower_dimension = max_tower_dimension,
    tower_separation = tower_separation, max_building_length = max_building_length,
    building_separation = building_separation, max_building_depth = max_building_depth,
    min_building_width = min_building_width,
    site_shape = if (!is.null(site_shape)) list(width = site_shape[1], depth = site_shape[2]),
    max_site_floorspace = max_site_floorspace, source = source
  )), class = "plancap_form")
}

#' Density rules
#'
#' Rules that limit the number of dwellings directly. Areas in m2.
#'
#' @param site_area_per_dwelling Net site area required per dwelling.
#' @param dwellings_per_ha Dwellings per hectare (an alternative statement).
#' @param min_site_area Minimum site area for development.
#' @param vacant_site_min_area Minimum area of a vacant site created by
#'   subdivision.
#' @param max_dwellings_per_site Cap on dwellings on one site.
#' @param minor_dwellings_per_site Additional minor (accessory) dwellings.
#' @param min_dwelling_size Minimum dwelling floor area.
#' @param large_site Large-site rules, a list with `area_per_dwelling`,
#'   `min_area` and optionally `max_average_area`.
#' @param access_width A data frame with `min`, `max` and `max_dwellings`:
#'   frontage or access width (m) to the most dwellings it may serve. A
#'   missing `max` is the open top band; a missing `max_dwellings` is no cap.
#' @param source Citation.
#' @return A list with class `plancap_density`.
#' @export
#' @examples
#' density(site_area_per_dwelling = 400, minor_dwellings_per_site = 1,
#'         source = "LLRZ-S1")
density <- function(site_area_per_dwelling = NULL, dwellings_per_ha = NULL,
                    min_site_area = NULL, vacant_site_min_area = NULL,
                    max_dwellings_per_site = NULL, minor_dwellings_per_site = NULL,
                    min_dwelling_size = NULL, large_site = NULL, access_width = NULL,
                    source = NULL) {
  for (a in c("site_area_per_dwelling", "dwellings_per_ha", "min_site_area",
              "vacant_site_min_area", "max_dwellings_per_site",
              "minor_dwellings_per_site", "min_dwelling_size")) {
    check_number(get(a), arg = a, lower = 0)
  }
  if (!is.null(access_width)) {
    access_width <- as.data.frame(access_width)
    if (!all(c("min", "max", "max_dwellings") %in% names(access_width))) {
      cli::cli_abort("{.arg access_width} needs columns {.field min}, {.field max}, {.field max_dwellings}.")
    }
    access_width <- lapply(seq_len(nrow(access_width)), function(i) {
      r <- access_width[i, ]
      compact(list(min = r[["min"]], max = if (!is.na(r[["max"]])) r[["max"]],
                   max_dwellings = if (!is.na(r$max_dwellings)) r$max_dwellings))
    })
  }
  structure(compact(list(
    site_area_per_dwelling = site_area_per_dwelling, dwellings_per_ha = dwellings_per_ha,
    min_site_area = min_site_area, vacant_site_min_area = vacant_site_min_area,
    max_dwellings_per_site = max_dwellings_per_site,
    minor_dwellings_per_site = minor_dwellings_per_site,
    min_dwelling_size = min_dwelling_size, large_site = large_site,
    access_width = access_width, source = source
  )), class = "plancap_density")
}

#' Uses a zone enables
#'
#' @param residential,business Whether each use is enabled.
#' @param residential_share Share of enabled floor area counted as
#'   residential in a zone that enables both: a number, or [bands()] by
#'   `"storey"` (e.g. `bands("storey", c(1, Inf), c(0, 1))` for a
#'   non-residential ground floor).
#' @param source Citation for the share (it is usually an assumption, not a
#'   rule, so say whose).
#' @return A list with class `plancap_use`.
#' @export
#' @examples
#' use_mix(residential = TRUE, business = TRUE, residential_share = 0.4,
#'         source = "Council split, 2023 HBA")
use_mix <- function(residential = TRUE, business = FALSE, residential_share = NULL,
                    source = NULL) {
  check_flag(residential, null_ok = FALSE)
  check_flag(business, null_ok = FALSE)
  if (inherits(residential_share, "plancap_bands")) {
    residential_share <- list(bands = unclass(residential_share))
  } else {
    check_number(residential_share, lower = 0, upper = 1)
  }
  if (is.null(residential_share)) residential_share <- if (residential && !business) 1 else if (!residential) 0
  structure(compact(list(residential = residential, business = business,
                         residential_share = residential_share, source = source)),
            class = "plancap_use")
}
