#' Plot capacity
#'
#' Plots of a capacity result. Each returns a ggplot object, so it can be
#' changed or added to, and carries a caption saying what the figures are.
#'
#' - `plot_capacity()`: ranked bars by any grouping of
#'   [summarise_capacity()], optionally stacked by a second (`fill`) and
#'   faceted (`facet`);
#' - `plot_height_profile()`: floor area by storey, where capacity sits
#'   vertically, optionally split by zone;
#' - `plot_distribution()`: the distribution of a per-site measure, a small
#'   histogram per zone;
#' - `plot_constraints()`: a waterfall from the theoretical maximum to the
#'   enabled floor area ([constraint_breakdown()]);
#' - `plot_capacity_map()`: a map of capacity per hectare, on sites, a grid
#'   or areas;
#' - `plot_cumulative()`: the capacity curve, sites ranked by capacity per
#'   hectare: the share of capacity on each share of the land.
#'
#' @param cap A capacity result from [estimate_capacity()].
#' @param by Grouping, as for [summarise_capacity()].
#' @param measure The measure to plot.
#' @param fill Optional second grouping, stacked within each bar.
#' @param facet Optional grouping for small multiples.
#' @param top Show at most this many bars; the rest are folded into
#'   "Other".
#' @param mode `"light"` or `"dark"` (see [theme_capacity()]).
#' @param ... Passed to [summarise_capacity()] (for example `breaks`).
#' @return A ggplot object.
#' @name plot_capacity
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' cap <- estimate_capacity(sc)
#' plot_capacity(cap)
#' plot_capacity(cap, measure = "dwellings", fill = "height_band")
#' plot_height_profile(cap, by = "zone")
#' plot_constraints(cap)
#' plot_capacity_map(cap, grid = 100)
#' plot_cumulative(cap)
NULL

#' @rdname plot_capacity
#' @export
plot_capacity <- function(cap, by = "zone", measure = "floor_area", fill = NULL, facet = NULL, top = 15,
                          mode = "light", ...) {
  check_capacity_object(cap)
  measure <- sub("^gfa$", "floor_area", measure)
  sm <- summarise_capacity(cap, by = c(by, fill, facet), measures = measure, ...)
  d <- as.data.frame(unclass(if (inherits(sm, "sf")) sf::st_drop_geometry(sm) else sm), stringsAsFactors = FALSE)
  keys <- by_columns(c(by, fill, facet))
  bk <- keys[1]
  d <- d[d[[measure]] != 0, , drop = FALSE]
  d$.bar <- fold_other(d[[bk]], d[[measure]], k = top)
  ink <- capacity_ink(mode)
  fmt <- measure_formatter(measure)
  if (is.null(fill)) {
    g <- stats::aggregate(d[measure], by = d[c(".bar", if (!is.null(facet)) by_columns(facet))], FUN = sum)
    g$.bar <- stats::reorder(g$.bar, g[[measure]])
    p <- ggplot2::ggplot(g, ggplot2::aes(x = .data[[measure]], y = .data$.bar)) +
      ggplot2::geom_col(fill = capacity_palette("categorical", 1, mode = mode), width = 0.5) +
      ggplot2::geom_text(ggplot2::aes(label = fmt(.data[[measure]])), hjust = -0.12, size = 3.2,
                         colour = ink$secondary)
  } else {
    fk <- by_columns(fill)
    d$.fill <- stable_levels(fold_other(d[[fk]], d[[measure]], k = 8), cap$rulebook, fill)
    if (is.ordered(d[[fk]])) d$.fill <- factor(as.character(d$.fill), levels = intersect(c(levels(d[[fk]]), "Other"), unique(as.character(d$.fill))))
    g <- stats::aggregate(d[measure], by = d[c(".bar", ".fill", if (!is.null(facet)) by_columns(facet))], FUN = sum)
    ord <- tapply(g[[measure]], g$.bar, sum)
    g$.bar <- factor(g$.bar, levels = names(sort(ord)))
    p <- ggplot2::ggplot(g, ggplot2::aes(x = .data[[measure]], y = .data$.bar, fill = .data$.fill)) +
      ggplot2::geom_col(width = 0.5, colour = ink$surface, linewidth = 0.4,
                        position = ggplot2::position_stack(reverse = TRUE)) +
      scale_fill_capacity_d(mode = mode, name = NULL)
  }
  if (!is.null(facet)) p <- p + ggplot2::facet_wrap(ggplot2::vars(.data[[by_columns(facet)]]))
  p + ggplot2::scale_x_continuous(labels = fmt, expand = ggplot2::expansion(mult = c(0, 0.12))) +
    ggplot2::labs(x = NULL, y = NULL, title = paste(measure_label(measure), "by", pretty_by(by)),
                  subtitle = cap$scenario, caption = wrap_text(plot_caption(cap$conversion), 110)) +
    theme_capacity(mode = mode, grid = "x")
}

pretty_by <- function(by) {
  lab <- c(zone = "zone", zone_key = "zone", height_band = "height", site_size_band = "site area",
           far_band = "floor area ratio", storeys = "storeys", binding = "what limits dwellings",
           dwelling_binding = "what limits dwellings", envelope_binding = "what limits the envelope",
           area = "area", grid = "grid cell", storey = "storey", path = "yield path")
  paste(vapply(by, function(b) lab[[b]] %||% gsub("_", " ", b), ""), collapse = " and ")
}

#' @rdname plot_capacity
#' @export
plot_height_profile <- function(cap, by = NULL, mode = "light") {
  check_capacity_object(cap)
  sm <- summarise_capacity(cap, by = c(by, "storey"), measures = "floor_area")
  d <- as.data.frame(unclass(sm), stringsAsFactors = FALSE)
  d$storey <- factor(d$storey, levels = sort(unique(d$storey)))
  ink <- capacity_ink(mode)
  if (is.null(by)) {
    p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$floor_area, y = .data$storey)) +
      ggplot2::geom_col(fill = capacity_palette("categorical", 1, mode = mode), width = 0.75)
  } else {
    k <- by_columns(by)
    d$.fill <- stable_levels(fold_other(d[[k]], d$floor_area, k = 8), cap$rulebook, by)
    p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$floor_area, y = .data$storey, fill = .data$.fill)) +
      ggplot2::geom_col(width = 0.75, colour = ink$surface, linewidth = 0.4,
                        position = ggplot2::position_stack(reverse = TRUE)) +
      scale_fill_capacity_d(mode = mode, name = NULL)
  }
  p + ggplot2::scale_x_continuous(labels = label_area, expand = ggplot2::expansion(mult = c(0, 0.05))) +
    ggplot2::labs(x = NULL, y = "Storey", title = "Floor area by storey",
                  subtitle = paste0(cap$scenario, ": where capacity sits vertically"),
                  caption = wrap_text(plot_caption(cap$conversion), 110)) +
    theme_capacity(mode = mode, grid = "x")
}

#' @rdname plot_capacity
#' @param bins Histogram bins.
#' @param log Whether to plot the measure on a log scale.
#' @param zones At most this many zones (the largest by site count).
#' @export
plot_distribution <- function(cap, measure = "floor_area", by = "zone", bins = 30, log = FALSE, zones = 6,
                              mode = "light") {
  check_capacity_object(cap)
  s <- sf::st_drop_geometry(cap$sites)
  k <- by_columns(by)
  s <- s[s[[measure]] > 0 & !is.na(s[[k]]), , drop = FALSE]
  n <- sort(table(s[[k]]), decreasing = TRUE)
  s <- s[s[[k]] %in% names(n)[seq_len(min(zones, length(n)))], , drop = FALSE]
  s$.group <- factor(s[[k]], levels = names(n))
  fmt <- measure_formatter(measure)
  p <- ggplot2::ggplot(s, ggplot2::aes(x = .data[[measure]])) +
    ggplot2::geom_histogram(bins = bins, fill = capacity_palette("categorical", 1, mode = mode),
                            colour = capacity_ink(mode)$surface, linewidth = 0.3) +
    ggplot2::facet_wrap(ggplot2::vars(.data$.group), scales = "free") +
    (if (log) ggplot2::scale_x_log10(labels = fmt) else ggplot2::scale_x_continuous(labels = fmt)) +
    ggplot2::labs(x = paste(measure_label(measure), "per site"), y = "Sites",
                  title = paste(measure_label(measure), "per site"),
                  subtitle = wrap_text(paste0(cap$scenario, ", sites with any capacity, by ", pretty_by(by))),
                  caption = wrap_text(plot_caption(cap$conversion), 110)) +
    theme_capacity(mode = mode, grid = "y")
  p
}

#' @rdname plot_capacity
#' @export
plot_constraints <- function(cap, mode = "light") {
  b <- constraint_breakdown(cap)
  waterfall(b$step, b$floor_area, first = "theoretical", last = "enabled", mode = mode,
            labels = c(theoretical = "Theoretical maximum", storeys_not_reached = "Storeys not reached",
                       setbacks_and_land = "Setbacks, planes and land", coverage = "Coverage",
                       landscaping = "Landscaping", impervious = "Impervious area", floorplate = "Floorplate",
                       tower_floorplate = "Tower floorplate", stack_monotonic = "Stack narrowing",
                       other_caps = "Other caps", far = "Floor area ratio",
                       max_site_floorspace = "Maximum site floorspace", enabled = "Enabled"),
            losses = TRUE) +
    ggplot2::labs(title = "From the theoretical maximum to enabled floor area",
                  subtitle = wrap_text(paste0(cap$scenario, ": every site built over its whole area to every storey its height allows, less each rule"), 95),
                  caption = wrap_text(plot_caption(cap$conversion), 110))
}

# A horizontal waterfall, read top to bottom: the first bar, each step
# floating from the running total, the last bar.
waterfall <- function(step, value, first, last, labels = NULL, mode = "light", losses = FALSE, fmt = label_area) {
  ink <- capacity_ink(mode)
  dv <- capacity_palette("diverging", mode = mode)
  n <- length(step)
  delta <- ifelse(step %in% c(first, last), value, if (losses) -value else value)
  start <- numeric(n)
  end <- numeric(n)
  run <- 0
  for (i in seq_len(n)) {
    if (step[i] == first) { start[i] <- 0; end[i] <- value[i]; run <- value[i] }
    else if (step[i] == last) { start[i] <- 0; end[i] <- value[i] }
    else { start[i] <- run; end[i] <- run + delta[i]; run <- end[i] }
  }
  kind <- ifelse(step %in% c(first, last), "total", ifelse(delta >= 0, "gain", "loss"))
  lab <- if (is.null(labels)) step else ifelse(step %in% names(labels), labels[step], step)
  d <- data.frame(step = factor(lab, levels = rev(unique(lab))), start = pmin(start, end), end = pmax(start, end),
                  value = delta, kind = kind, y = rev(seq_len(n)))
  cols <- c(total = capacity_palette("categorical", 1, mode = mode), gain = dv[["gain"]], loss = dv[["loss"]])
  if (losses) cols[["total"]] <- ink$secondary
  d$label <- ifelse(d$kind == "total", fmt(d$value), label_signed(fmt)(d$value))
  shown <- intersect(c("gain", "loss"), d$kind)
  ggplot2::ggplot(d) +
    ggplot2::geom_rect(ggplot2::aes(xmin = .data$start, xmax = .data$end, ymin = .data$y - 0.25, ymax = .data$y + 0.25,
                                    fill = .data$kind)) +
    ggplot2::geom_text(ggplot2::aes(x = .data$end, y = .data$y, label = .data$label), hjust = -0.1, size = 3.1,
                       colour = ink$secondary) +
    ggplot2::scale_fill_manual(values = cols, breaks = shown, labels = c(gain = "Adds", loss = "Removes")[shown],
                               name = NULL, drop = TRUE, guide = if (length(shown) > 1) "legend" else "none") +
    ggplot2::scale_y_continuous(breaks = d$y, labels = as.character(d$step), expand = ggplot2::expansion(add = 0.5)) +
    ggplot2::scale_x_continuous(labels = fmt, expand = ggplot2::expansion(mult = c(0, 0.16))) +
    ggplot2::labs(x = NULL, y = NULL) +
    theme_capacity(mode = mode, grid = "x")
}

#' @rdname plot_capacity
#' @param grid,areas,area_id Plot on a square grid of `grid` metres, or on
#'   `areas` labelled by `area_id`, instead of on sites.
#' @param per_ha Whether to map the measure per hectare of land.
#' @param basemap `TRUE` to draw a basemap (Esri's World Gray Canvas), or the
#'   name of a maptiles provider; fetched with the maptiles and tidyterra
#'   packages, so it needs an internet connection.
#' @export
plot_capacity_map <- function(cap, measure = "floor_area", grid = NULL, areas = NULL, area_id = NULL,
                              per_ha = TRUE, mode = "light", basemap = FALSE) {
  check_capacity_object(cap)
  ink <- capacity_ink(mode)
  if (!is.null(grid) || !is.null(areas)) {
    by <- if (!is.null(grid)) "grid" else "area"
    d <- summarise_capacity(cap, by = by, measures = c(measure, "land_area"), grid = grid, areas = areas,
                            area_id = area_id)
    d <- sf::st_as_sf(as.data.frame(d))
    unit <- if (by == "grid") paste0(grid, " m cells") else "areas"
  } else {
    d <- cap$sites[, c("site_id", measure)]
    d$land_area <- cap$sites$area
    unit <- "sites"
  }
  d$value <- if (per_ha) ifelse(d$land_area > 0, d[[measure]] / d$land_area * 10000, NA) else d[[measure]]
  lab <- if (per_ha) paste(measure_label(measure), "per hectare") else measure_label(measure)
  fmt <- measure_formatter(measure)
  use_base <- !isFALSE(basemap)
  if (use_base) d <- sf::st_transform(d, 3857)
  ggplot2::ggplot(d) +
    (if (use_base) basemap_layer(d, basemap)) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data$value), colour = ink$surface, linewidth = if (unit == "sites") 0.05 else 0.2,
                     alpha = if (use_base) 0.85 else 1) +
    scale_fill_capacity_c(mode = mode, name = NULL, labels = fmt, na.value = ink$neutral) +
    ggplot2::coord_sf(datum = NA, crs = sf::st_crs(d), expand = FALSE) +
    ggplot2::labs(title = lab, subtitle = paste0(cap$scenario, ", on ", unit),
                  caption = wrap_text(paste(plot_caption(cap$conversion), if (use_base) basemap_credit(basemap)), 90)) +
    theme_capacity(mode = mode, grid = "none") +
    ggplot2::theme(axis.text = ggplot2::element_blank(), legend.key.width = ggplot2::unit(2.5, "lines"))
}

#' @rdname plot_capacity
#' @export
plot_cumulative <- function(cap, measure = "dwellings", by = NULL, mode = "light") {
  check_capacity_object(cap)
  s <- sf::st_drop_geometry(cap$sites)
  s <- s[s$area > 0, , drop = FALSE]
  k <- if (is.null(by)) NULL else by_columns(by)
  grp <- if (is.null(k)) rep("All sites", nrow(s)) else as.character(fold_other(s[[k]], s[[measure]], k = 4))
  curve <- do.call(rbind, lapply(split(seq_len(nrow(s)), grp), function(i) {
    x <- s[i, , drop = FALSE]
    o <- order(-x[[measure]] / x$area)
    tot_land <- sum(x$area)
    tot <- sum(x[[measure]])
    data.frame(group = grp[i[1]], land = c(0, cumsum(x$area[o]) / tot_land),
               share = c(0, if (tot > 0) cumsum(x[[measure]][o]) / tot else rep(0, length(o))))
  }))
  ink <- capacity_ink(mode)
  pct <- function(x) paste0(round(100 * x), "%")
  p <- ggplot2::ggplot(curve, ggplot2::aes(x = .data$land, y = .data$share)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = ink$reference, linewidth = 0.4) +
    ggplot2::scale_x_continuous(labels = pct, limits = c(0, 1), expand = ggplot2::expansion(mult = 0.01)) +
    ggplot2::scale_y_continuous(labels = pct, limits = c(0, 1), expand = ggplot2::expansion(mult = 0.01))
  p <- if (is.null(k)) {
    p + ggplot2::geom_line(colour = capacity_palette("categorical", 1, mode = mode), linewidth = 0.8)
  } else {
    p + ggplot2::geom_line(ggplot2::aes(colour = .data$group), linewidth = 0.8) +
      scale_colour_capacity_d(mode = mode, name = NULL)
  }
  p + ggplot2::coord_equal() +
    ggplot2::labs(x = "Share of land (sites ranked by capacity per hectare)", y = paste("Share of", tolower(measure_label(measure))),
                  title = paste("Where", tolower(measure_label(measure)), "are"),
                  subtitle = wrap_text(paste0(cap$scenario, ": the share on each share of the land; the diagonal is an even spread"), 70),
                  caption = wrap_text(plot_caption(cap$conversion), 110)) +
    theme_capacity(mode = mode, grid = "both")
}
