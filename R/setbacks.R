#' Setback rules: yards, planes and everything that keeps a building back
#'
#' Every rule that keeps a building a distance from a boundary, from a simple
#' yard to a recession plane, a sky exposure plane or a setback proportional to
#' height, is held as a **setback**: a required distance from an origin line as
#' a function of height, \eqn{d(h)}. The engine takes, for each boundary at
#' each storey, the largest distance any applicable rule requires.
#'
#' - `yard()`: a fixed distance (or a formula), optionally only from a storey
#'   or above a height.
#' - `plane()`: a recession / daylight / height-in-relation-to-boundary
#'   plane, rising at an angle from a start height above the origin line.
#' - `upper_level_setback()`: an extra setback for the part of a building
#'   above a height (a podium step-back).
#' - `proportional_setback()`: a distance proportional to height, with a
#'   minimum and maximum (e.g. Germany's 0.4H, at least 3 m).
#' - `setback_profile()`: any piecewise-linear \eqn{d(h)}, for rules none of
#'   the above express.
#'
#' Use [setback_distance()] to evaluate one.
#'
#' @param distance Required distance (m), or a formula string. For
#'   `setback_profile()`, the distances (m) required at each of `height`.
#' @param boundaries Boundary classes the rule applies to, e.g. `"road"`,
#'   `"side"`, `"rear"`. See [boundary_classes()].
#' @param value_from Instead of `distance`, a yard set by what is already
#'   there: `"existing_front_setback"` is the average setback of the dwellings
#'   on the neighbouring sites along the street (as the Auckland Unitary
#'   Plan's Special Character Areas front yard, D18.6.1.3.1), measured from
#'   building outlines ([find_existing_front_setbacks()]). Where nothing could
#'   be measured the rule is reported as not applied, never read as no yard.
#' @param from_storey Applies only from this storey up (1 = ground).
#' @param above_height Applies only to the part of a building above this
#'   height (m).
#' @param origin Line the distance is measured from: `"boundary"` (default),
#'   `"road_far_side"` (the far side of the road in front, as Japan's road
#'   slant line) or `"road_centreline"`.
#' @param when Conditions under which the rule applies, from [conditions()].
#' @param variant Name of the alternative standard this rule belongs to. Rules
#'   of different variants are alternatives, never combined.
#' @param name Optional label for the rule.
#' @param source Citation (plan, chapter, rule number).
#' @param activity_status Optional activity status of the standard.
#' @return A list with class `plancap_setback`.
#' @export
#' @examples
#' yard(3, "road", source = "Rule 7.1")
#' plane(angle_deg = 45, start_height = 2.5, boundaries = c("side", "rear"))
#' # NYC-style sky exposure plane on wide streets: 5.6 vertical to 1 horizontal
#' plane(slope = 5.6, start_height = 85 * 0.3048, boundaries = "road")
#' proportional_setback(0.4, min = 3, boundaries = c("side", "rear"))
#' setback_profile(height = c(0, 3.6, 6.9, 30), distance = c(1, 1, 2, 25.1),
#'                 boundaries = c("side", "rear"))
yard <- function(distance = NULL, boundaries, from_storey = NULL, above_height = NULL,
                 origin = "boundary", when = NULL, variant = NULL, name = NULL,
                 source = NULL, activity_status = NULL, value_from = NULL) {
  if (is.null(value_from)) {
    check_value(distance, null_ok = FALSE)
    if (is.numeric(distance)) check_number(distance, lower = 0)
  } else {
    check_choice(value_from, "existing_front_setback")
    if (!is.null(distance)) cli::cli_abort("Give {.arg distance} or {.arg value_from}, not both.")
  }
  new_setback("yard", list(distance = distance, value_from = value_from, from_storey = from_storey,
                           above_height = above_height),
              boundaries, origin, when, variant, name, source, activity_status)
}

#' @rdname yard
#' @param angle_deg Plane angle from horizontal, degrees.
#' @param slope Alternative to `angle_deg`: rise per unit of horizontal run
#'   (e.g. `2.7` for a 2.7:1 plane).
#' @param start_height Height (m) above the origin line where the plane
#'   starts.
#' @param set_in Horizontal distance (m) inside the origin line where the
#'   plane starts.
#' @param angle_by_bearing Optional: angles that vary with the direction the
#'   boundary faces, as a data frame with `from_deg`, `to_deg` and `angle_deg`
#'   (bearing of the outward normal, clockwise from north).
#' @param angle_by_orientation Optional: angles at the four cardinal bearings,
#'   `c(north = , east = , south = , west = )`, graded linearly in between
#'   (Christchurch's recession plane diagrams work this way).
#' @param vertical_above Height (m) above which the plane turns vertical: the
#'   setback stays at its value at this height.
#' @param max_setback_above Optional cap on the plane's setback above a
#'   height, by the direction the boundary faces:
#'   `c(height = , north = , east = , south = , west = )`. Above `height` the
#'   lesser of the plane and this setback applies.
#' @param datum Ground the start height is measured from: `"boundary"` (ground
#'   at the boundary, the default), `"site"` (site mean ground) or `"road"`.
#' @export
plane <- function(angle_deg = NULL, start_height, boundaries, slope = NULL,
                  set_in = 0, angle_by_bearing = NULL, angle_by_orientation = NULL,
                  vertical_above = NULL, max_setback_above = NULL, datum = "boundary",
                  origin = "boundary", when = NULL, variant = NULL, name = NULL,
                  source = NULL, activity_status = NULL) {
  if (is.null(angle_deg) == is.null(slope) && is.null(angle_by_bearing) &&
      is.null(angle_by_orientation)) {
    cli::cli_abort("Give exactly one of {.arg angle_deg} or {.arg slope}.")
  }
  card <- c("north", "east", "south", "west")
  if (!is.null(angle_by_orientation)) {
    if (!is.numeric(angle_by_orientation) || !setequal(names(angle_by_orientation), card)) {
      cli::cli_abort("{.arg angle_by_orientation} needs named {.field north}, {.field east}, {.field south}, {.field west}.")
    }
    angle_by_orientation <- as.list(angle_by_orientation[card])
  }
  if (!is.null(max_setback_above)) {
    if (!is.numeric(max_setback_above) || !setequal(names(max_setback_above), c("height", card))) {
      cli::cli_abort("{.arg max_setback_above} needs named {.field height}, {.field north}, {.field east}, {.field south}, {.field west}.")
    }
    max_setback_above <- as.list(max_setback_above[c("height", card)])
  }
  check_number(vertical_above, lower = 0)
  if (!is.null(slope)) {
    check_number(slope, lower = 0)
    angle_deg <- atan(slope) * 180 / pi
  }
  check_number(angle_deg, lower = 0, upper = 90)
  if (is.null(angle_deg) && !is.null(angle_by_orientation)) {
    angle_deg <- min(unlist(angle_by_orientation))  # fallback where bearing is unknown
  }
  check_value(start_height, null_ok = FALSE)
  check_number(set_in, lower = 0)
  check_choice(datum, c("boundary", "site", "road"))
  if (!is.null(angle_by_bearing)) {
    angle_by_bearing <- as.data.frame(angle_by_bearing)
    if (!all(c("from_deg", "to_deg", "angle_deg") %in% names(angle_by_bearing))) {
      cli::cli_abort("{.arg angle_by_bearing} needs columns {.field from_deg}, {.field to_deg}, {.field angle_deg}.")
    }
    angle_by_bearing <- lapply(seq_len(nrow(angle_by_bearing)),
                               function(i) as.list(angle_by_bearing[i, c("from_deg", "to_deg", "angle_deg")]))
  }
  new_setback("plane", list(angle_deg = angle_deg, start_height = start_height,
                            set_in = if (set_in > 0) set_in else NULL,
                            angle_by_bearing = angle_by_bearing,
                            angle_by_orientation = angle_by_orientation,
                            vertical_above = vertical_above,
                            max_setback_above = max_setback_above,
                            datum = if (datum != "boundary") datum else NULL),
              boundaries, origin, when, variant, name, source, activity_status)
}

#' @rdname yard
#' @export
upper_level_setback <- function(distance, boundaries, above_height = NULL,
                                from_storey = NULL, origin = "boundary",
                                when = NULL, variant = NULL, name = NULL,
                                source = NULL, activity_status = NULL) {
  if (is.null(above_height) && is.null(from_storey)) {
    cli::cli_abort("Give {.arg above_height} or {.arg from_storey}.")
  }
  check_value(distance, null_ok = FALSE)
  new_setback("upper_level", list(distance = distance, above_height = above_height,
                                  from_storey = from_storey),
              boundaries, origin, when, variant, name, source, activity_status)
}

#' @rdname yard
#' @param ratio Distance per metre of height.
#' @param min,max Bounds on the distance (m).
#' @export
proportional_setback <- function(ratio, boundaries, min = 0, max = NULL,
                                 origin = "boundary", when = NULL, variant = NULL,
                                 name = NULL, source = NULL, activity_status = NULL) {
  check_number(ratio, lower = 0)
  check_number(min, lower = 0)
  check_number(max, lower = 0)
  new_setback("proportional", list(ratio = ratio, min = if (min > 0) min else NULL, max = max),
              boundaries, origin, when, variant, name, source, activity_status)
}

#' @rdname yard
#' @param height For `setback_profile()`: breakpoints of height (m,
#'   ascending). Distances between breakpoints are interpolated; beyond the
#'   last they stay at the last.
#' @export
setback_profile <- function(height, distance, boundaries, origin = "boundary",
                            when = NULL, variant = NULL, name = NULL,
                            source = NULL, activity_status = NULL) {
  if (!is.numeric(height) || is.unsorted(height, strictly = TRUE)) {
    cli::cli_abort("{.arg height} must be strictly ascending numbers.")
  }
  if (!is.numeric(distance) || length(distance) != length(height) || any(distance < 0)) {
    cli::cli_abort("{.arg distance} must be non-negative numbers, one per height.")
  }
  new_setback("profile", list(points = lapply(seq_along(height),
                                              function(i) c(height[i], distance[i]))),
              boundaries, origin, when, variant, name, source, activity_status)
}

new_setback <- function(kind, fields, boundaries, origin, when, variant, name,
                        source, activity_status, call = rlang::caller_env()) {
  check_character(boundaries, null_ok = FALSE, call = call)
  check_choice(origin, c("boundary", "road_far_side", "road_centreline"), call = call)
  check_string(variant, call = call)
  check_string(name, call = call)
  check_string(source, call = call)
  check_string(activity_status, call = call)
  check_number(fields$from_storey, arg = "from_storey", lower = 1, call = call)
  check_number(fields$above_height, arg = "above_height", lower = 0, call = call)
  if (!is.null(when) && !inherits(when, "plancap_conditions")) {
    cli::cli_abort("{.arg when} must come from {.fn conditions}.", call = call)
  }
  structure(
    compact(c(list(kind = kind, name = name), fields,
              list(boundaries = boundaries,
                   origin = if (origin != "boundary") origin else NULL,
                   when = if (!is.null(when)) unclass(when) else NULL,
                   variant = variant, activity_status = activity_status,
                   source = source))),
    class = "plancap_setback"
  )
}

#' Required setback distance at a height
#'
#' Evaluates a setback rule at one or more heights. The engine calls this for
#' every boundary at every storey; it is exported so rules can be checked and
#' plotted on their own.
#'
#' @param rule A setback from [yard()], [plane()] and friends (or the same
#'   structure read from a rulebook file).
#' @param height Height(s) above the datum (m) at which to evaluate.
#' @param storey Storey number(s) for rules with `from_storey`; defaults to
#'   `NA`, which counts as satisfying any storey condition.
#' @param bearing Bearing(s) of the boundary's outward normal (degrees
#'   clockwise from north), for planes whose angle depends on orientation.
#' @param vars Other variables for formula values, see [eval_rule_value()].
#' @param slope_in For planes on sloping ground: how fast the site's ground
#'   rises into the site from the boundary (metres per metre).
#' @param base_height The building's own height above the site's ground, where
#'   `height` has been adjusted to the boundary's ground; a plane's
#'   `max_setback_above` is tested against it.
#' @param measured For a yard with `value_from`: the measured distance (m)
#'   per height (`NA` where nothing was measured).
#' @return Numeric vector of required distances (m), one per height.
#' @export
#' @examples
#' p <- plane(angle_deg = 45, start_height = 2.5, boundaries = "side")
#' setback_distance(p, c(2, 3, 6, 9))
#' setback_distance(proportional_setback(0.4, "side", min = 3), c(3, 10, 20))
setback_distance <- function(rule, height, storey = NA_integer_, bearing = NA_real_,
                             vars = list(), slope_in = 0, base_height = height, measured = NULL) {
  n <- length(height)
  storey <- rep_len(storey, n)
  vars$H <- height
  if (!is.null(vars$storey)) storey <- rep_len(vars$storey, n)
  d <- switch(rule$kind,
    yard = if (!is.null(rule$value_from)) rep_len(measured %||% NA_real_, n) else
      rep_len(eval_rule_value(rule$distance, vars), n),
    upper_level = rep_len(eval_rule_value(rule$distance, vars), n),
    plane = {
      bearing <- rep_len(bearing, n)
      angle <- rep_len(rule$angle_deg %||% NA_real_, n)
      if (!is.null(rule$angle_by_bearing)) {
        angle <- angle_for_bearing(rule$angle_by_bearing, bearing, angle)
      }
      if (!is.null(rule$angle_by_orientation)) {
        graded <- graded_angle(rule$angle_by_orientation, bearing)
        angle <- ifelse(is.na(graded), angle, graded)
      }
      start <- rep_len(eval_rule_value(rule$start_height, vars), n)
      h <- height
      if (!is.null(rule$vertical_above)) h <- pmin(h, rule$vertical_above)
      t <- tan(angle * pi / 180)
      # On sloping ground the site's ground rises into the site (slope_in, rise
      # per metre), which slows the building's gain on the plane
      # (capacityengine hirb_setback()).
      s <- rep_len(slope_in, n)
      s[is.na(s)] <- 0
      si <- rule$set_in %||% 0
      d <- si + pmax(0, (h - start + s * si) / pmax(t - s, 0.1 * t))
      cap <- rule$max_setback_above
      if (!is.null(cap)) {
        fixed <- graded_angle(cap[c("north", "east", "south", "west")], bearing)
        above <- rep_len(base_height, n) > cap$height & !is.na(fixed)
        d[above] <- pmin(d[above], fixed[above])
      }
      d
    },
    proportional = {
      x <- rule$ratio * height
      x <- pmax(x, rule[["min"]] %||% 0)
      if (!is.null(rule[["max"]])) x <- pmin(x, rule[["max"]])
      x
    },
    profile = {
      pts <- do.call(rbind, lapply(rule$points, unlist))
      stats::approx(pts[, 1], pts[, 2], xout = height, rule = 2)$y
    },
    cli::cli_abort("Unknown setback kind {.val {rule$kind}}.")
  )
  applies <- rep(TRUE, n)
  if (!is.null(rule$from_storey)) applies <- applies & (is.na(storey) | storey >= rule$from_storey)
  if (!is.null(rule$above_height)) applies <- applies & height > rule$above_height
  ifelse(applies, d, 0)
}

# Linear interpolation between values given at north, east, south and west,
# by the bearing (degrees clockwise from north) the boundary faces.
graded_angle <- function(card, bearing) {
  v <- unlist(card[c("north", "east", "south", "west")])
  b <- bearing %% 360
  stats::approx(c(0, 90, 180, 270, 360), c(v, v[1]), xout = b)$y
}

angle_for_bearing <- function(table, bearing, default) {
  out <- rep(default %||% NA_real_, length(bearing))
  for (row in table) {
    from <- row$from_deg %% 360
    to <- row$to_deg %% 360
    b <- bearing %% 360
    hit <- if (from <= to) b >= from & b < to else b >= from | b < to
    out[!is.na(hit) & hit] <- row$angle_deg
  }
  out
}

#' Boundary classes
#'
#' The classes a boundary segment can be given by the morphology helpers, and
#' that setback rules key off. A rulebook may add its own classes for
#' boundaries identified from a layer (e.g. `"rail"`).
#'
#' @return Character vector.
#' @export
#' @examples
#' boundary_classes()
boundary_classes <- function() {
  c("road", "side", "rear", "internal", "common", "coastal", "riparian",
    "lakeside", "reserve", "rail")
}

#' Conditions under which a rule applies
#'
#' Attach to any setback (or other rule) with its `when` argument. All the
#' conditions given must hold. A condition the engine cannot evaluate, because
#' the layer it needs was not supplied, is not applied, and is counted and
#' reported with the direction of the error it causes.
#'
#' @param min_site_area,max_site_area Site area bounds (m2).
#' @param rear_sites `"include"` (default), `"exclude"` or `"only"`.
#' @param corner_sites `"include"` (default), `"exclude"` or `"only"`.
#' @param within_frontage,beyond_frontage Applies only to boundary segments
#'   whose midpoint is within, or beyond, this distance (m) of the road
#'   frontage.
#' @param frontage_depth_share Applies only beyond this share of site depth
#'   from the frontage (e.g. Christchurch's "front 60 per cent" exemption is
#'   `0.6`).
#' @param adjacent_zones,not_adjacent_zones Zone keys or family names across
#'   the boundary that make the rule apply, or that stop it applying.
#' @param facing Bearing range `c(from, to)` of the boundary's outward normal
#'   (degrees clockwise from north) for the rule to apply. A rule for "a site
#'   on the southern boundary of its neighbour" faces north: `c(315, 45)`.
#' @param min_road_width,max_road_width Road reserve width bounds (m).
#' @param min_slope,max_slope Site slope bounds (per cent).
#' @param distance_to Name of a layer, with `min_distance` / `max_distance`,
#'   for rules that apply within a distance of a feature (e.g. a station).
#' @param min_distance,max_distance Distance bounds (m) to `distance_to`.
#' @return A list with class `plancap_conditions`.
#' @export
#' @examples
#' conditions(adjacent_zones = "RES_ANY", min_site_area = 1000)
#' conditions(distance_to = "transit", max_distance = 800)
conditions <- function(min_site_area = NULL, max_site_area = NULL,
                       rear_sites = NULL, corner_sites = NULL,
                       within_frontage = NULL, beyond_frontage = NULL,
                       frontage_depth_share = NULL,
                       adjacent_zones = NULL, not_adjacent_zones = NULL,
                       facing = NULL, min_road_width = NULL, max_road_width = NULL,
                       min_slope = NULL, max_slope = NULL, distance_to = NULL,
                       min_distance = NULL, max_distance = NULL) {
  for (a in c("min_site_area", "max_site_area", "within_frontage", "beyond_frontage",
              "min_road_width", "max_road_width", "min_slope", "max_slope",
              "min_distance", "max_distance")) {
    check_number(get(a), arg = a, lower = 0)
  }
  check_number(frontage_depth_share, lower = 0, upper = 1)
  check_choice(rear_sites, c("include", "exclude", "only"))
  check_choice(corner_sites, c("include", "exclude", "only"))
  check_character(adjacent_zones)
  check_character(not_adjacent_zones)
  check_string(distance_to)
  if (!is.null(facing) && (!is.numeric(facing) || length(facing) != 2)) {
    cli::cli_abort("{.arg facing} must be two bearings, {.code c(from, to)}.")
  }
  if (xor(is.null(distance_to), is.null(min_distance) && is.null(max_distance))) {
    cli::cli_abort("{.arg distance_to} needs {.arg min_distance} or {.arg max_distance}, and vice versa.")
  }
  structure(compact(list(
    min_site_area = min_site_area, max_site_area = max_site_area,
    rear_sites = rear_sites, corner_sites = corner_sites,
    within_frontage = within_frontage, beyond_frontage = beyond_frontage,
    frontage_depth_share = frontage_depth_share,
    adjacent_zones = adjacent_zones, not_adjacent_zones = not_adjacent_zones,
    facing = facing, min_road_width = min_road_width, max_road_width = max_road_width,
    min_slope = min_slope, max_slope = max_slope, distance_to = distance_to,
    min_distance = min_distance, max_distance = max_distance
  )), class = "plancap_conditions")
}
