#' Overlays: spatial layers that change the rules
#'
#' An overlay is a map layer that changes what the zone allows wherever it
#' applies. The spatial data is supplied at run time under the overlay's
#' `layer` name; the rulebook holds only what the overlay does.
#'
#' @param id Identifier.
#' @param type What the overlay does:
#'   * `"height"`: a height limit, a fixed `value` or read from `value_field`
#'     (optionally through `value_map`);
#'   * `"height_surface"`: a raster surface of maximum height (airport
#'     surfaces, viewshafts, sunlight planes);
#'   * `"exclusion"`: land under the overlay is taken out of the buildable area
#'     (hazards, designations, tree protection);
#'   * `"parameters"`: replaces or adjusts named zone parameters, given as
#'     [zone_changes()];
#'   * `"flag"`: tags the site and changes nothing.
#' @param layer Name of the layer supplied at run time.
#' @param combine How the overlay's value combines with the zone's (see
#'   *Combining rules* below). Defaults: `"cap"` for heights,
#'   `"replace"` for parameters.
#' @param value,value_field,value_map Fixed value, or the attribute holding it,
#'   or a named list mapping attribute codes to values.
#' @param floor_value A height always allowed regardless of the surface, so
#'   the effective height is `max(surface, floor_value)`.
#' @param height_conversion For height overlays whose mapped value is total
#'   height: a list with `table` (a data frame or list of `total` and
#'   `occupiable`), and optionally `passthrough_below`, `passthrough_above` and
#'   `between` (`"passthrough"`, `"interpolate"` or `"snap_nearest"`) for
#'   values the table does not list.
#' @param surface_datum For height surfaces: `"absolute"` if the raster holds
#'   elevations (the scenario then needs a `dem`), `"ground"` if it holds
#'   heights above ground.
#' @param filter Named list: attribute to accepted values, applied when the
#'   layer is read.
#' @param removes For exclusions: `"all"` (every building) or `"residential"`
#'   (dwellings only).
#' @param buffer For exclusions: distance (m) to buffer the features by, or
#'   the name of an attribute holding it (e.g. a tree protection radius).
#' @param applies_to_zones Zone keys the overlay applies in; `NULL` for all.
#' @param parameters For `type = "parameters"`: a [zone_changes()].
#' @param additions A [zone_changes()] whose setbacks are added to the zone's
#'   own instead of replacing them (e.g. an extra yard).
#' @param enabled Whether a run uses the overlay unless told otherwise.
#' @param precedence Tie-break between overlays: higher wins.
#' @param label,source,notes Description and citation.
#'
#' @section Combining rules:
#' Every applicable rule produces a limit, and each declares how its limit
#' combines with the others:
#' * `"cap"`: the most restrictive wins (the default for limits);
#' * `"replace"`: replaces the zone's value even if more permissive;
#' * `"floor"`: a minimum entitlement that cannot be taken away;
#' * `"add"` / `"multiply"`: bonuses and percentage adjustments.
#'
#' Evaluation order is fixed: zone, then areas (precincts), then overlays,
#' then bonuses, then entitlements.
#' @return A list with class `plancap_overlay`.
#' @seealso [add_overlay()]
#' @export
#' @examples
#' overlay("height_control", "height", layer = "height_areas",
#'         value_field = "max_height_m", combine = "replace",
#'         source = "Planning maps, height control")
#' overlay("flood", "exclusion", layer = "flood_hazard", source = "Rule 9.2")
overlay <- function(id, type = c("height", "height_surface", "exclusion", "parameters", "flag"),
                    layer, combine = NULL, value = NULL, value_field = NULL,
                    value_map = NULL, floor_value = NULL, height_conversion = NULL,
                    surface_datum = NULL, filter = NULL,
                    removes = NULL, buffer = NULL, applies_to_zones = NULL,
                    parameters = NULL, additions = NULL, enabled = TRUE,
                    precedence = 0, label = NULL, source = NULL, notes = NULL) {
  check_string(id, null_ok = FALSE)
  type <- rlang::arg_match(type)
  if (!is.null(additions) && !inherits(additions, "plancap_zone_changes")) {
    cli::cli_abort("{.arg additions} must come from {.fn zone_changes}.")
  }
  check_string(layer, null_ok = FALSE)
  combine <- combine %||% switch(type, height = , height_surface = "cap",
                                 parameters = "replace", NULL)
  check_choice(combine, c("cap", "replace", "floor", "add", "multiply"))
  check_value(value)
  check_string(value_field)
  check_number(floor_value, lower = 0)
  check_choice(surface_datum, c("absolute", "ground"))
  if (!is.null(height_conversion)) {
    tb <- height_conversion$table
    if (is.data.frame(tb)) tb <- lapply(seq_len(nrow(tb)), function(i) as.list(tb[i, c("total", "occupiable")]))
    height_conversion$table <- tb
  }
  check_choice(removes, c("all", "residential"))
  if (!is.null(buffer) && !is_number(buffer) && !is_string(buffer)) {
    cli::cli_abort("{.arg buffer} must be a distance or an attribute name.")
  }
  check_character(applies_to_zones)
  check_flag(enabled, null_ok = FALSE)
  check_number(precedence, null_ok = FALSE)
  if (type == "parameters" && !inherits(parameters, "plancap_zone_changes")) {
    cli::cli_abort("A {.val parameters} overlay needs {.arg parameters} from {.fn zone_changes}.")
  }
  if (type == "height" && is.null(value) && is.null(value_field)) {
    cli::cli_abort("A {.val height} overlay needs {.arg value} or {.arg value_field}.")
  }
  if (type == "exclusion" && is.null(removes)) removes <- "all"
  o <- compact(list(
    label = label, type = type, layer = layer, combine = combine, value = value,
    value_field = value_field, value_map = value_map, floor_value = floor_value,
    height_conversion = height_conversion, surface_datum = surface_datum,
    filter = filter, removes = removes, buffer = buffer,
    applies_to_zones = applies_to_zones,
    parameters = if (!is.null(parameters)) unclass(parameters),
    additions = if (!is.null(additions)) unclass(additions),
    enabled = enabled, precedence = precedence, source = source, notes = notes
  ))
  structure(o, id = id, class = "plancap_overlay")
}

#' Areas: precincts, sub-precincts and site-specific controls
#'
#' An area is a mapped place with its own rules that *replace* the zone's
#' (where an overlay usually only caps them). Sub-areas refine the area's
#' rules for parts of it, keyed by an attribute of the area layer.
#'
#' @param id Identifier.
#' @param layer Name of the layer supplied at run time.
#' @param filter Named list: attribute to accepted values.
#' @param applies_to_zones Zone keys the area changes; `NULL` for all.
#' @param parameters A [zone_changes()] applied to every zone in the area.
#' @param additions A [zone_changes()] whose setbacks are added to the zone's
#'   own instead of replacing them.
#' @param zone_parameters Named list of [zone_changes()], by zone key, for
#'   changes that differ by zone.
#' @param sub_area_field Attribute of the layer naming the sub-area.
#' @param sub_areas Named list, by sub-area value, of [zone_changes()] or
#'   [sub_area()].
#' @param max_dwellings,min_dwellings,max_floorspace Totals across the whole
#'   area (e.g. a precinct capped at 2,000 dwellings).
#' @param combine `"replace"` (default) or `"cap"`.
#' @param label,source,notes Description and citation.
#' @return A list with class `plancap_area`.
#' @seealso [add_area()]
#' @export
#' @examples
#' area("quarry", layer = "precincts",
#'      parameters = zone_changes(height = height_limit(16, source = "I1.6.1")),
#'      sub_area_field = "sub_precinct",
#'      sub_areas = list(B = zone_changes(height = height_limit(20, source = "I1.6.1(b)"))),
#'      source = "Quarry Precinct")
area <- function(id, layer, filter = NULL, applies_to_zones = NULL, parameters = NULL,
                 additions = NULL, zone_parameters = NULL, sub_area_field = NULL, sub_areas = NULL,
                 max_dwellings = NULL, min_dwellings = NULL, max_floorspace = NULL,
                 combine = "replace", label = NULL, source = NULL, notes = NULL) {
  check_string(id, null_ok = FALSE)
  check_string(layer, null_ok = FALSE)
  check_character(applies_to_zones)
  check_choice(combine, c("replace", "cap"))
  check_string(sub_area_field)
  for (a in c("max_dwellings", "min_dwellings", "max_floorspace")) {
    check_number(get(a), arg = a, lower = 0)
  }
  is_changes <- function(x) inherits(x, "plancap_zone_changes")
  if (!is.null(parameters) && !is_changes(parameters)) {
    cli::cli_abort("{.arg parameters} must come from {.fn zone_changes}.")
  }
  if (!is.null(additions) && !is_changes(additions)) {
    cli::cli_abort("{.arg additions} must come from {.fn zone_changes}.")
  }
  if (!is.null(zone_parameters) && (!is.list(zone_parameters) || is.null(names(zone_parameters)) ||
                                     !all(vapply(zone_parameters, is_changes, logical(1))))) {
    cli::cli_abort("{.arg zone_parameters} must be a named list of {.fn zone_changes}.")
  }
  ok_sub <- function(x) is_changes(x) || inherits(x, "plancap_sub_area")
  if (!is.null(sub_areas) && (!is.list(sub_areas) || is.null(names(sub_areas)) ||
                              !all(vapply(sub_areas, ok_sub, logical(1))))) {
    cli::cli_abort("{.arg sub_areas} must be a named list of {.fn zone_changes} or {.fn sub_area}.")
  }
  if (!is.null(sub_areas) && is.null(sub_area_field)) {
    cli::cli_abort("{.arg sub_areas} needs {.arg sub_area_field}.")
  }
  a <- compact(list(
    label = label, layer = layer, filter = filter, applies_to_zones = applies_to_zones,
    combine = combine,
    parameters = if (!is.null(parameters)) unclass(parameters),
    additions = if (!is.null(additions)) unclass(additions),
    zone_parameters = if (!is.null(zone_parameters)) lapply(zone_parameters, unclass),
    sub_area_field = sub_area_field,
    sub_areas = if (!is.null(sub_areas)) lapply(sub_areas, unclass),
    totals = compact(list(max_dwellings = max_dwellings, min_dwellings = min_dwellings,
                          max_floorspace = max_floorspace)),
    source = source, notes = notes
  ))
  if (!length(a$totals)) a$totals <- NULL
  structure(a, id = id, class = "plancap_area")
}

#' A sub-area of an area
#'
#' Most sub-areas only change the area's rules, which [zone_changes()] says.
#' Use `sub_area()` when a sub-area also adds setbacks, changes rules for one
#' zone only, or caps dwellings (alone or shared with other sub-areas).
#'
#' @param changes A [zone_changes()].
#' @param additions A [zone_changes()] whose setbacks are added to the zone's.
#' @param zone_parameters Named list of [zone_changes()] by zone key.
#' @param max_dwellings,min_dwellings,max_floorspace Totals for the sub-area.
#' @param total_group Sub-areas with the same `total_group` share one total.
#' @return A list with class `plancap_sub_area`.
#' @export
#' @examples
#' sub_area(zone_changes(height = height_limit(20, source = "I1.6.1(b)")),
#'          max_dwellings = 120, total_group = "BCD")
sub_area <- function(changes = zone_changes(), additions = NULL, zone_parameters = NULL,
                     max_dwellings = NULL, min_dwellings = NULL, max_floorspace = NULL,
                     total_group = NULL) {
  if (!inherits(changes, "plancap_zone_changes")) {
    cli::cli_abort("{.arg changes} must come from {.fn zone_changes}.")
  }
  if (!is.null(additions) && !inherits(additions, "plancap_zone_changes")) {
    cli::cli_abort("{.arg additions} must come from {.fn zone_changes}.")
  }
  check_string(total_group)
  for (a in c("max_dwellings", "min_dwellings", "max_floorspace")) {
    check_number(get(a), arg = a, lower = 0)
  }
  totals <- compact(list(max_dwellings = max_dwellings, min_dwellings = min_dwellings,
                         max_floorspace = max_floorspace))
  x <- c(unclass(changes), compact(list(
    additions = if (!is.null(additions)) unclass(additions),
    zone_parameters = if (!is.null(zone_parameters)) lapply(zone_parameters, unclass),
    totals = if (length(totals)) totals, total_group = total_group)))
  structure(x, class = "plancap_sub_area")
}

#' Bonuses and entitlements
#'
#' A **bonus** adds to or multiplies a limit when a condition is met (a floor
#' area bonus for affordable housing, a density bonus). Bonuses are reported
#' in separate `*_with_bonus` results and never folded into the base
#' plan-enabled figure.
#'
#' An **entitlement** is a minimum a plan or a higher law guarantees whatever
#' the local rules say (three dwellings per site as of right; two units on a
#' lot). It combines as a floor: the most permissive of it and the local rules
#' wins.
#'
#' @param id Identifier.
#' @param quantity What is changed: `"far"`, `"height"`, `"dwellings"` or
#'   `"floor_area"`.
#' @param value Amount added, multiplier, or guaranteed minimum.
#' @param combine For bonuses: `"add"` or `"multiply"`.
#' @param applies_to_zones Zone keys; `NULL` for all.
#' @param cap Upper limit on the bonus-inclusive value.
#' @param condition Text describing what must be provided to earn the bonus.
#' @param layer Optional layer limiting where it applies.
#' @param when Optional [conditions()].
#' @param label,source Description and citation.
#' @return A list with class `plancap_bonus` or `plancap_entitlement`.
#' @export
#' @examples
#' bonus("affordable", "far", 0.5, combine = "add", applies_to_zones = "TC",
#'       condition = "10% of dwellings affordable", source = "Rule 12.4")
#' entitlement("mdrs", "dwellings", 3, applies_to_zones = c("MDR", "HDR"),
#'             source = "RMA Schedule 3A, clause 10")
bonus <- function(id, quantity = c("far", "height", "dwellings", "floor_area"), value,
                  combine = c("add", "multiply"), applies_to_zones = NULL, cap = NULL,
                  condition = NULL, layer = NULL, when = NULL, label = NULL,
                  source = NULL) {
  check_string(id, null_ok = FALSE)
  quantity <- rlang::arg_match(quantity)
  combine <- rlang::arg_match(combine)
  check_value(value, null_ok = FALSE)
  check_number(cap)
  check_character(applies_to_zones)
  check_string(condition)
  check_string(layer)
  structure(compact(list(label = label, quantity = quantity, value = value,
                         combine = combine, applies_to_zones = applies_to_zones,
                         cap = cap, condition = condition, layer = layer,
                         when = if (!is.null(when)) unclass(when), source = source)),
            id = id, class = "plancap_bonus")
}

#' @rdname bonus
#' @export
entitlement <- function(id, quantity = c("dwellings", "height", "floor_area"), value,
                        applies_to_zones = NULL, layer = NULL, when = NULL,
                        label = NULL, source = NULL) {
  check_string(id, null_ok = FALSE)
  quantity <- rlang::arg_match(quantity)
  check_number(value, lower = 0, null_ok = FALSE)
  check_character(applies_to_zones)
  structure(compact(list(label = label, quantity = quantity, value = value,
                         combine = "floor", applies_to_zones = applies_to_zones,
                         layer = layer, when = if (!is.null(when)) unclass(when),
                         source = source)),
            id = id, class = "plancap_entitlement")
}

#' Record a rule that is not modelled
#'
#' Every rulebook keeps a register of the rules it leaves out, so the omission
#' is visible to anyone reading the results.
#'
#' @param rule The rule, in words.
#' @param reason Why it is not modelled.
#' @param zones Zone keys it affects; `NULL` for all or unknown.
#' @param likely_effect What leaving it out does to capacity: `"overstates"`
#'   (modelling it would lower capacity), `"understates"`, `"either"` or
#'   `"unknown"`.
#' @param size Estimated size of the effect, where known (free text).
#' @param source Citation.
#' @return A list with class `plancap_unmodelled`.
#' @export
#' @examples
#' unmodelled_rule("Rail corridor setback of 1.5 m",
#'                 reason = "No rail boundary class in the cadastre",
#'                 likely_effect = "overstates")
unmodelled_rule <- function(rule, reason, zones = NULL,
                            likely_effect = c("overstates", "understates", "either", "unknown"),
                            size = NULL, source = NULL) {
  check_string(rule, null_ok = FALSE)
  check_string(reason, null_ok = FALSE)
  check_character(zones)
  likely_effect <- rlang::arg_match(likely_effect)
  structure(compact(list(rule = rule, reason = reason, zones = zones,
                         likely_effect = likely_effect, size = size, source = source)),
            class = "plancap_unmodelled")
}
