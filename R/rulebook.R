#' Create a rulebook
#'
#' A rulebook holds every planning rule for one plan (or one scenario of it),
#' with a citation for every value. Build it with the `add_*()` and `set_*()`
#' functions, or read it from a file with [read_rulebook()].
#'
#' @param name Name of the plan.
#' @param id Short identifier, e.g. `"wcc-dp-2024"`.
#' @param jurisdiction Council, city or state.
#' @param country ISO country code.
#' @param effective_date Date the rules are as at (`"YYYY-MM-DD"`).
#' @param source Where the rules were read from.
#' @param units `"m"` (default) or `"ft"`: units of every length and area in
#'   the rulebook. Results are always computed in metres.
#' @param hemisphere `"south"` or `"north"`, for rules that depend on which way
#'   a boundary faces. If `NULL` it is inferred from the data at run time.
#' @return A `plancap_rulebook`.
#' @export
#' @examples
#' rb <- rulebook("Exampleton District Plan", id = "exampleton-dp",
#'                jurisdiction = "Exampleton", country = "NZ")
#' rb <- add_zone(rb, zone("LDR", "Low Density Residential",
#'   height = height_limit(8, source = "LDR-S1"),
#'   setbacks = list(yard(3, "road", source = "LDR-S2")),
#'   coverage = ratio(0.35, source = "LDR-S3")))
#' rb
rulebook <- function(name, id = NULL, jurisdiction = NULL, country = NULL,
                     effective_date = NULL, source = NULL, units = c("m", "ft"),
                     hemisphere = NULL) {
  check_string(name, null_ok = FALSE)
  check_string(id)
  check_string(jurisdiction)
  check_string(country)
  check_string(effective_date)
  check_string(source)
  units <- rlang::arg_match(units)
  check_choice(hemisphere, c("south", "north"))
  id <- id %||% gsub("[^a-z0-9]+", "-", tolower(name))
  new_rulebook(list(
    schema_version = rulebook_schema_version(),
    plan = compact(list(id = id, name = name, jurisdiction = jurisdiction,
                        country = country, effective_date = effective_date,
                        source = source, units = units, hemisphere = hemisphere)),
    defaults = rulebook_defaults(),
    variant_choice = "max",
    zones = list()
  ))
}

new_rulebook <- function(x) structure(x, class = "plancap_rulebook")

rulebook_schema_version <- function() "0.1"

#' Rulebook defaults
#'
#' Run-wide assumptions a rulebook may override with [set_defaults()].
#'
#' @return A named list:
#' \describe{
#'   \item{`storey_height`}{Storey height (m) where the zone and height rule
#'     do not imply one. 3.}
#'   \item{`min_floorplate`}{Smallest storey worth building (m2); smaller
#'     storeys end the stack. 30.}
#'   \item{`level_reference`}{Where each storey is tested against height and
#'     planes: `"ceiling"` (the default; a storey must fit entirely) or
#'     `"floor"`.}
#'   \item{`no_limit_height`}{Stand-in height (m) for zones with no height
#'     limit; `NULL` means such zones are flagged and given no stand-in.}
#'   \item{`large_site`}{Large-site treatment: `threshold` (m2, 10,000),
#'     `deduction` (share of land for roads and reserves, 0.25) and `method`
#'     (`"divisor"`: dwellings = net land / area per dwelling; or
#'     `"envelope"`).}
#' }
#' @export
#' @examples
#' rulebook_defaults()
rulebook_defaults <- function() {
  list(storey_height = 3, min_floorplate = 30, level_reference = "ceiling",
       large_site = list(threshold = 10000, deduction = 0.25, method = "divisor"))
}

#' Morphology defaults
#'
#' The assumptions behind identifying what each boundary and site is (road
#' frontage, side or rear boundary, corner site, rear site, access leg). Each
#' can be overridden in a rulebook with [set_morphology()] and again for a
#' single run.
#'
#' @return A named list:
#' \describe{
#'   \item{`min_road_contact`}{Shortest total road frontage (m) for a site to
#'     count as fronting a road. 0.5.}
#'   \item{`road_tolerance`}{Distance (m) within which a boundary counts as
#'     running along a road parcel, absorbing cadastral slivers. A boundary
#'     segment is a road frontage when at least half its length is within it.
#'     0.5.}
#'   \item{`boundary_probe_distance`}{How far (m) across a side or rear
#'     boundary to look for the zone opposite. 1.}
#'   \item{`road_probe_distance`}{How far (m) across a road boundary to look
#'     for the zone opposite, so the probe clears the carriageway. 25.}
#'   \item{`side_rear_angle_tolerance`}{Degrees from parallel to the frontage
#'     within which a boundary is a rear boundary. 30.}
#'   \item{`rear_depth_share`}{How far back (as a share of the site's depth
#'     from the frontage) a parallel boundary must sit to be a rear boundary.
#'     0.5.}
#'   \item{`rear_site_max_frontage`}{A site with less road frontage than this
#'     (m) is a rear site. 7.5.}
#'   \item{`corner_angle_tolerance`}{Degrees by which two frontages must differ
#'     in bearing for a corner site. 30.}
#'   \item{`corner_min_frontage`}{Shortest frontage (m) on each road for a
#'     corner site. 3.}
#'   \item{`through_min_bearing_difference`}{Degrees between two frontages for
#'     a through site. 135.}
#'   \item{`access_leg_max_width`}{Widest (m) an access leg (driveway strip of
#'     a rear site) may be. 7.5.}
#'   \item{`access_leg_min_road_contact`}{Shortest road contact (m) of an
#'     access leg. 0.5.}
#'   \item{`exclude_access_legs`}{Whether access legs are left out of net site
#'     area. `TRUE`.}
#'   \item{`boundary_merge_angle`}{Degrees within which consecutive boundary
#'     segments count as one straight boundary. 5.}
#'   \item{`water_boundary_distance`}{Distance (m) from a water feature within
#'     which a boundary is classed coastal, riparian or lakeside. 20.}
#'   \item{`reserve_families`}{Zone families whose land makes a boundary a
#'     reserve boundary. `"OPEN_SPACE"`.}
#'   \item{`min_sliver_area`}{Pieces of a site (m2) smaller than this, left by
#'     a zone boundary, are merged into the larger piece. 1.}
#' }
#' @export
#' @examples
#' morphology_defaults()$corner_angle_tolerance
morphology_defaults <- function() {
  list(min_road_contact = 0.5, road_tolerance = 0.5, road_probe_distance = 25,
       boundary_probe_distance = 1, side_rear_angle_tolerance = 30,
       rear_depth_share = 0.5, rear_site_max_frontage = 7.5, corner_angle_tolerance = 30,
       corner_min_frontage = 3, through_min_bearing_difference = 135,
       access_leg_max_width = 7.5, access_leg_min_road_contact = 0.5,
       exclude_access_legs = TRUE, boundary_merge_angle = 5,
       water_boundary_distance = 20, reserve_families = "OPEN_SPACE",
       min_sliver_area = 1)
}

#' Floor area to dwellings conversion
#'
#' Dwellings are a derived view of floor area. Give either one average
#' dwelling size or a unit mix.
#'
#' @param dwelling_size Average gross floor area per dwelling (m2), including
#'   its share of circulation.
#' @param unit_mix A data frame with `name`, `size` (m2) and `share`
#'   (summing to 1).
#' @param efficiency Share of gross floor area that is saleable or lettable,
#'   applied before dividing by dwelling size. 1 if `dwelling_size` is already
#'   a gross figure.
#' @param min_one_dwelling If `TRUE`, a site enabling residential floor area
#'   of at least `min_one_dwelling_floor` (or, if that is not set, the zone's
#'   minimum dwelling size) yields at least one dwelling.
#' @param min_one_dwelling_floor Residential floor area (m2) at or above which a
#'   site counts at least one dwelling.
#' @param source Citation or reasoning for the assumption.
#' @return A list with class `plancap_conversion`.
#' @export
#' @examples
#' conversion(dwelling_size = 100, source = "Assumed average")
#' conversion(unit_mix = data.frame(name = c("1br", "2br", "3br"),
#'                                  size = c(50, 75, 100),
#'                                  share = c(0.3, 0.5, 0.2)),
#'            efficiency = 0.85)
conversion <- function(dwelling_size = NULL, unit_mix = NULL, efficiency = 1,
                       min_one_dwelling = TRUE, min_one_dwelling_floor = NULL,
                       source = NULL) {
  check_number(min_one_dwelling_floor, lower = 0)
  if (is.null(dwelling_size) == is.null(unit_mix)) {
    cli::cli_abort("Give exactly one of {.arg dwelling_size} or {.arg unit_mix}.")
  }
  check_number(dwelling_size, lower = 1)
  check_number(efficiency, lower = 0, upper = 1, null_ok = FALSE)
  check_flag(min_one_dwelling, null_ok = FALSE)
  if (!is.null(unit_mix)) {
    unit_mix <- as.data.frame(unit_mix)
    if (!all(c("name", "size", "share") %in% names(unit_mix))) {
      cli::cli_abort("{.arg unit_mix} needs columns {.field name}, {.field size}, {.field share}.")
    }
    if (abs(sum(unit_mix$share) - 1) > 1e-6) cli::cli_abort("Unit mix shares must sum to 1.")
    unit_mix <- lapply(seq_len(nrow(unit_mix)), function(i) {
      list(name = as.character(unit_mix$name[i]), size = unit_mix$size[i],
           share = unit_mix$share[i])
    })
  }
  structure(compact(list(dwelling_size = dwelling_size, unit_mix = unit_mix,
                         efficiency = efficiency, min_one_dwelling = min_one_dwelling,
                         min_one_dwelling_floor = min_one_dwelling_floor,
                         source = source)),
            class = "plancap_conversion")
}

#' Add rules to a rulebook
#'
#' Pipe-friendly functions that add zones, overlays, areas, bonuses,
#' entitlements and unmodelled-rule records to a rulebook.
#'
#' @param rb A `plancap_rulebook`.
#' @param ... Objects from [zone()], [overlay()], [area()], [bonus()],
#'   [entitlement()] or [unmodelled_rule()] respectively.
#' @param codes For `add_zone()`: the zone codes in the zoning layer that map
#'   to this zone. Defaults to the zone key. Only valid with one zone.
#' @return The updated rulebook.
#' @name add_rules
#' @examples
#' rb <- rulebook("Exampleton District Plan")
#' rb <- rb |>
#'   add_zone(zone("OS", "Open Space", method = "none")) |>
#'   add_overlay(overlay("flood", "exclusion", layer = "flood_hazard")) |>
#'   add_unmodelled(unmodelled_rule("Outlook space", "Placement of windows",
#'                                  likely_effect = "overstates"))
#' names(rb$zones)
NULL

#' @rdname add_rules
#' @export
add_zone <- function(rb, ..., codes = NULL) {
  check_rulebook(rb)
  zs <- list(...)
  if (!length(zs)) cli::cli_abort("Give at least one {.fn zone}.")
  if (!is.null(codes) && length(zs) > 1) cli::cli_abort("{.arg codes} works with one zone at a time.")
  for (z in zs) {
    if (!inherits(z, "plancap_zone")) cli::cli_abort("{.fn add_zone} takes objects from {.fn zone}.")
    key <- attr(z, "key")
    if (key %in% names(rb$zones)) cli::cli_warn("Replacing zone {.val {key}}.")
    zz <- unclass(z)
    attr(zz, "key") <- NULL
    rb$zones[[key]] <- zz
    for (code in (codes %||% key)) rb$zone_map[[code]] <- key
  }
  rb
}

#' @rdname add_rules
#' @export
add_overlay <- function(rb, ...) add_named(rb, "overlays", "plancap_overlay", "overlay", ...)

#' @rdname add_rules
#' @export
add_area <- function(rb, ...) add_named(rb, "areas", "plancap_area", "area", ...)

#' @rdname add_rules
#' @export
add_bonus <- function(rb, ...) add_named(rb, "bonuses", "plancap_bonus", "bonus", ...)

#' @rdname add_rules
#' @export
add_entitlement <- function(rb, ...) {
  add_named(rb, "entitlements", "plancap_entitlement", "entitlement", ...)
}

#' @rdname add_rules
#' @export
add_unmodelled <- function(rb, ...) {
  check_rulebook(rb)
  for (u in list(...)) {
    if (!inherits(u, "plancap_unmodelled")) {
      cli::cli_abort("{.fn add_unmodelled} takes objects from {.fn unmodelled_rule}.")
    }
    rb$unmodelled_rules[[length(rb$unmodelled_rules) + 1]] <- unclass(u)
  }
  rb
}

add_named <- function(rb, slot, cls, fn, ..., call = rlang::caller_env()) {
  check_rulebook(rb, call = call)
  for (x in list(...)) {
    if (!inherits(x, cls)) cli::cli_abort("Expected objects from {.fn {fn}}.", call = call)
    id <- attr(x, "id")
    xx <- unclass(x)
    attr(xx, "id") <- NULL
    rb[[slot]][[id]] <- xx
  }
  rb
}

#' Set rulebook-wide settings
#'
#' @param rb A `plancap_rulebook`.
#' @param ... Named values. For `set_zone_map()`: zone code = zone key. For
#'   `set_zone_families()`: family name = character vector of zone keys. For
#'   `set_defaults()` and `set_morphology()`: names from
#'   [rulebook_defaults()] and [morphology_defaults()].
#' @return The updated rulebook.
#' @name set_rules
#' @examples
#' rb <- rulebook("Exampleton District Plan") |>
#'   set_zone_families(RESIDENTIAL = c("LDR", "MDR", "HDR")) |>
#'   set_morphology(corner_angle_tolerance = 25) |>
#'   set_conversion(conversion(dwelling_size = 90))
#' rb$morphology
NULL

#' @rdname set_rules
#' @export
set_zone_map <- function(rb, ...) {
  check_rulebook(rb)
  m <- list(...)
  if (length(m) == 1 && is.null(names(m)) && is.character(m[[1]])) m <- as.list(m[[1]])
  if (is.null(names(m)) || any(!nzchar(names(m)))) cli::cli_abort("Zone map entries must be named by code.")
  for (code in names(m)) {
    check_string(m[[code]], arg = code, null_ok = FALSE)
    rb$zone_map[[code]] <- m[[code]]
  }
  rb
}

#' @rdname set_rules
#' @export
set_zone_families <- function(rb, ...) {
  check_rulebook(rb)
  f <- list(...)
  if (is.null(names(f)) || any(!nzchar(names(f)))) cli::cli_abort("Families must be named.")
  for (nm in names(f)) {
    check_character(f[[nm]], arg = nm, null_ok = FALSE)
    rb$zone_families[[nm]] <- f[[nm]]
  }
  rb
}

#' @rdname set_rules
#' @export
set_defaults <- function(rb, ...) {
  check_rulebook(rb)
  d <- list(...)
  bad <- setdiff(names(d), c(names(rulebook_defaults()), "ground_floor_height",
                             "no_limit_height"))
  if (length(bad)) cli::cli_abort("Unknown default{?s}: {.field {bad}}.")
  rb$defaults <- merge_lists(rb$defaults %||% rulebook_defaults(), d)
  rb
}

#' @rdname set_rules
#' @export
set_morphology <- function(rb, ...) {
  check_rulebook(rb)
  m <- list(...)
  bad <- setdiff(names(m), names(morphology_defaults()))
  if (length(bad)) cli::cli_abort("Unknown morphology setting{?s}: {.field {bad}}.")
  rb$morphology <- merge_lists(rb$morphology %||% list(), m)
  rb
}

#' @rdname set_rules
#' @param x For `set_conversion()`: a [conversion()].
#' @export
set_conversion <- function(rb, x) {
  check_rulebook(rb)
  if (!inherits(x, "plancap_conversion")) cli::cli_abort("{.arg x} must come from {.fn conversion}.")
  rb$conversion <- unclass(x)
  rb
}

#' @rdname set_rules
#' @param mode For `set_ground()`: how the ground budget treats paving.
#'   `"most_restrictive"` (default; footprint is the least of coverage and
#'   what landscaping and impervious limits leave, assuming no paving),
#'   `"with_access"` (also deducts measured access legs and any parking and
#'   manoeuvring allowance) or `"full"` (also deducts outdoor space required
#'   per dwelling).
#' @param overlap For `set_ground()`: named logicals saying which ground may
#'   count twice: `outdoor_living_counts_as_landscaping`,
#'   `landscaping_on_structure`, `deep_soil_counts_as_landscaping`.
#' @param parking_area_per_dwelling For `set_ground()`: surface parking and
#'   manoeuvring area (m2) needed per dwelling in `"with_access"` and `"full"`
#'   modes.
#' @param outdoor_area_per_dwelling For `set_ground()`: outdoor living space
#'   (m2) at ground per dwelling in `"full"` mode.
#' @export
set_ground <- function(rb, mode = c("most_restrictive", "with_access", "full"),
                       overlap = NULL, parking_area_per_dwelling = NULL,
                       outdoor_area_per_dwelling = NULL) {
  check_rulebook(rb)
  mode <- rlang::arg_match(mode)
  check_number(parking_area_per_dwelling, lower = 0)
  check_number(outdoor_area_per_dwelling, lower = 0)
  ok <- c("outdoor_living_counts_as_landscaping", "landscaping_on_structure",
          "deep_soil_counts_as_landscaping")
  if (!is.null(overlap)) {
    overlap <- as.list(overlap)
    bad <- setdiff(names(overlap), ok)
    if (length(bad)) cli::cli_abort("Unknown overlap setting{?s}: {.field {bad}}.")
  }
  rb$ground <- compact(list(mode = mode, overlap = overlap,
                            parking_area_per_dwelling = parking_area_per_dwelling,
                            outdoor_area_per_dwelling = outdoor_area_per_dwelling))
  rb
}

#' @rdname set_rules
#' @param choice For `set_variant_choice()`: `"max"` (default: each site takes
#'   the most enabling of its permitted alternative standards), `"min"`, or
#'   the name of one variant.
#' @export
set_variant_choice <- function(rb, choice = "max") {
  check_rulebook(rb)
  check_string(choice, null_ok = FALSE)
  rb$variant_choice <- choice
  rb
}

check_rulebook <- function(rb, call = rlang::caller_env()) {
  if (!inherits(rb, "plancap_rulebook")) {
    cli::cli_abort("Expected a rulebook from {.fn rulebook} or {.fn read_rulebook}.", call = call)
  }
  invisible(rb)
}

#' @export
print.plancap_rulebook <- function(x, ...) {
  p <- x$plan
  cli::cli_text("{.strong <plancap rulebook>} {p$name}")
  meta <- c(p$id, p$jurisdiction, p$country, if (!is.null(p$effective_date)) paste("as at", p$effective_date))
  cli::cli_text("{.emph {paste(meta, collapse = ' | ')}}")
  units <- if ((p$units %||% "m") == "ft") "feet" else "metres"
  n <- function(s) length(x[[s]])
  cli::cli_text("{n('zones')} zone{?s}, {n('overlays')} overlay{?s}, {n('areas')} area{?s}, \\
                 {n('bonuses')} bonus{?es}, {n('entitlements')} entitlement{?s}; \\
                 {n('unmodelled_rules')} unmodelled rule{?s}. Units: {units}.")
  if (n("zones")) {
    zt <- zone_summary_table(x)
    print(zt, row.names = FALSE, right = FALSE)
  }
  invisible(x)
}

zone_summary_table <- function(rb) {
  fmt <- function(v) {
    if (is.null(v)) return("")
    if (is.list(v)) return(if (!is.null(v$bands)) "bands" else fmt(v$value))
    if (is.numeric(v)) return(format(v, trim = TRUE))
    as.character(v)
  }
  codes <- split(names(rb$zone_map), unlist(rb$zone_map, use.names = FALSE))
  data.frame(
    zone = names(rb$zones),
    label = vapply(rb$zones, function(z) z$label %||% "", ""),
    method = vapply(rb$zones, function(z) z$method %||% "", ""),
    height = vapply(rb$zones, function(z) {
      h <- z$height
      if (is.null(h)) "" else if (!is.null(h$from_overlay)) paste0("<", h$from_overlay, ">")
      else if (isTRUE(h$no_limit)) "no limit" else fmt(h$value)
    }, ""),
    setbacks = vapply(rb$zones, function(z) length(z$setbacks), 1L),
    coverage = vapply(rb$zones, function(z) fmt(z$ratios$coverage_max), ""),
    codes = vapply(names(rb$zones), function(k) paste(codes[[k]] %||% "", collapse = ","), ""),
    stringsAsFactors = FALSE
  )
}

#' @export
print.plancap_setback <- function(x, ...) {
  cli::cli_text("{.strong <setback: {x$kind}>} on {.val {x$boundaries}}")
  utils::str(unclass(x)[setdiff(names(x), c("kind", "boundaries"))], give.head = FALSE,
             no.list = TRUE)
  invisible(x)
}
