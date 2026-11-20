#' Convert a rulebook between metres and feet
#'
#' Every length and area in a rulebook is in the units its `plan$units`
#' declares. This converts all of them, including inside formulas and bands,
#' so a rulebook written in feet can be checked in metres or written back out
#' in feet. The engine always works in metres.
#'
#' Ratios, angles, storey counts and dwellings per hectare are unit-free and
#' left alone.
#'
#' @param rb A `plancap_rulebook`.
#' @param to `"m"` or `"ft"`.
#' @return The converted rulebook.
#' @export
#' @examples
#' rb <- rulebook("Example Code", units = "ft") |>
#'   add_zone(zone("R1", height = height_limit(35),
#'                 setbacks = list(yard(20, "road"))))
#' m <- convert_rulebook_units(rb, "m")
#' m$zones$R1$height$value
convert_rulebook_units <- function(rb, to = c("m", "ft")) {
  check_rulebook(rb)
  to <- rlang::arg_match(to)
  from <- rb$plan$units %||% "m"
  if (from == to) return(rb)
  k <- if (from == "ft") 0.3048 else 1 / 0.3048
  x <- unit_walk(to_plain(rb), k)
  x$plan$units <- to
  normalise_rulebook(x)
}

length_keys <- c(
  "distance", "start_height", "set_in", "above_height", "storey_height",
  "ground_floor_height", "no_limit_height", "within_frontage", "beyond_frontage",
  "min_road_width", "max_road_width", "min_distance", "max_distance",
  "max_tower_dimension", "tower_separation", "max_building_length",
  "max_building_depth", "min_building_width", "tower_above_height", "floor_value",
  "occupiable", "roof_allowance", "width", "depth", "min_road_contact",
  "road_probe_distance", "corner_min_frontage", "access_leg_max_width",
  "access_leg_min_road_contact", "water_boundary_distance", "buffer", "vertical_above",
  "road_tolerance", "boundary_probe_distance", "rear_site_max_frontage"
)
area_keys <- c(
  "min_site_area", "max_site_area", "site_area_per_dwelling", "vacant_site_min_area",
  "min_dwelling_size", "dwelling_size", "size", "max_floorplate", "min_floorplate",
  "max_tower_floorplate", "max_site_floorspace", "area_per_dwelling", "min_area",
  "max_average_area", "threshold", "max_floorspace", "min_sliver_area",
  "parking_area_per_dwelling", "outdoor_area_per_dwelling", "min_one_dwelling_floor", "max_area"
)
by_dim <- c(site_area = "area", height = "length", road_width = "length",
            distance = "length", site_depth = "length", storey = NA, slope = NA)

unit_scale <- function(v, dim, k) {
  if (is.null(v) || is.na(dim)) return(v)
  f <- if (dim == "length") k else k^2
  if (is.numeric(v)) return(v * f)
  if (is_string(v)) return(convert_formula(v, k, dim))
  v
}

# Rewrite a formula written in one unit system so it takes variables in the
# other and returns its result in the other.
convert_formula <- function(text, k, dim) {
  expr <- parse_rule_formula(text)
  len_vars <- c("H", "site_depth", "site_width", "frontage", "road_width", "distance")
  sub <- function(e) {
    if (is.symbol(e)) {
      nm <- as.character(e)
      if (nm %in% len_vars) return(call("(", call("/", e, k)))
      if (nm == "site_area") return(call("(", call("/", e, k^2)))
      return(e)
    }
    if (is.call(e)) {
      for (i in seq_along(e)[-1]) e[[i]] <- sub(e[[i]])
    }
    e
  }
  out <- sub(expr)
  if (!is.na(dim)) out <- call("*", call("(", out), if (dim == "length") k else k^2)
  paste(deparse(out, width.cutoff = 500L), collapse = " ")
}

unit_walk <- function(x, k, key = "", value_dim = NA) {
  if (key == "unmodelled_rules") return(x)  # free text only
  if (!is.list(x)) {
    dim <- if (key == "value") value_dim else if (key %in% length_keys) "length"
           else if (key %in% area_keys) "area" else NA
    if (key == "buffer" && is_string(x)) return(x)  # attribute name
    return(unit_scale(x, dim, k))
  }
  if (is.null(names(x))) return(lapply(x, unit_walk, k = k, key = key, value_dim = value_dim))

  # A bands object: bounds follow `by`, values follow the owner.
  if (!is.null(x$by) && !is.null(x$bands)) {
    bd <- by_dim[[x$by]]
    x$bands <- lapply(x$bands, function(b) {
      b$min <- unit_scale(b$min, bd, k)
      b$max <- unit_scale(b$max, bd, k)
      b$value <- unit_scale(b$value, value_dim, k)
      b
    })
    return(x)
  }
  child_dim <- value_dim
  if (key %in% c("height", "building_separation")) child_dim <- "length"
  if (!is.null(x$type) && x$type %in% c("height", "height_surface")) child_dim <- "length"
  if (!is.null(x$quantity)) child_dim <- switch(x$quantity, height = "length",
                                                floor_area = "area", NA)
  for (nm in names(x)) {
    v <- x[[nm]]
    if (nm == "points") {
      x[[nm]] <- lapply(v, function(p) unlist(p) * k)
    } else if (nm == "height_conversion") {
      v$table <- lapply(v$table, function(r) { r$total <- r$total * k; r$occupiable <- r$occupiable * k; r })
      for (f in c("passthrough_below", "passthrough_above")) if (!is.null(v[[f]])) v[[f]] <- v[[f]] * k
      x[[nm]] <- v
    } else if (nm == "max_setback_above") {
      x[[nm]] <- lapply(v, function(e) e * k)  # a height and four distances
    } else if (nm == "angle_by_orientation") {
      x[[nm]] <- v  # angles
    } else if (nm %in% c("min", "max") && (identical(x$kind, "proportional") || key == "access_width")) {
      x[[nm]] <- unit_scale(v, "length", k)
    } else if (nm == "value_map") {
      x[[nm]] <- if (identical(child_dim, "length")) lapply(v, function(e) e * k) else v
    } else if (nm == "access_width") {
      x[[nm]] <- lapply(v, function(r) unit_walk(r, k, "access_width", NA))
    } else if (nm == "bands" && is.list(v) && !is.null(v$by)) {
      x[[nm]] <- unit_walk(v, k, nm, child_dim)
    } else {
      x[nm] <- list(unit_walk(v, k, nm, child_dim))
    }
  }
  x
}
