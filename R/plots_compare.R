#' Plot a scenario comparison
#'
#' - `plot_comparison()`: each zone (or height band, area or grid cell) in
#'   the baseline and the scenario, as a dumbbell from one to the other, or
#'   as bars of the change;
#' - `plot_change_map()`: where capacity rises and falls, on sites or grid
#'   cells, in a diverging scale;
#' - `plot_transitions()`: the land (or capacity) moving from each baseline
#'   zone to each scenario zone, as a matrix;
#' - `plot_attribution()`: a waterfall from the baseline total, through each
#'   driver of the change, to the scenario total.
#'
#' @param cmp A comparison from [compare_scenarios()].
#' @param pair Which pair of the comparison (a name or number).
#' @param by `"zone"`, `"height"`, `"area"` or `"grid"` (the last two need
#'   the comparison run with `areas` or `grid`).
#' @param measure The measure.
#' @param type `"dumbbell"` or `"bars"`.
#' @param top Show at most this many groups, the largest changes.
#' @param mode `"light"` or `"dark"`.
#' @return A ggplot object.
#' @name plot_comparison
#' @examples
#' \donttest{
#' town <- exampleton()
#' pc1 <- exampleton_pc1()
#' base <- scenario("Operative", rulebook_example("exampleton"),
#'                  parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                  roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                  zoning = town$zoning, layers = town[c("height_areas", "flood_hazard", "transit")])
#' change <- scenario_change(base, "PC1", rulebook = pc1$rulebook, zoning = pc1$zoning)
#' cmp <- compare_scenarios(run_scenarios(scenario_set(base, change)), grid = 200)
#' plot_comparison(cmp)
#' plot_change_map(cmp, on = "grid")
#' plot_transitions(cmp)
#' plot_attribution(cmp)
#' }
NULL

get_pair <- function(cmp, pair) {
  if (!inherits(cmp, "plancap_comparison")) cli::cli_abort("{.arg cmp} must come from {.fn compare_scenarios}.")
  p <- cmp$pairs[[pair]]
  if (is.null(p)) cli::cli_abort("No pair {.val {pair}} in this comparison.")
  p
}
pair_caption <- function(cmp) {
  paste("Plan-enabled, gross, blank-slate capacity in both scenarios; baseline", cmp$baseline, "\u2192 each change.")
}

#' @rdname plot_comparison
#' @export
plot_comparison <- function(cmp, by = "zone", measure = "floor_area", type = c("dumbbell", "bars"), pair = 1,
                            top = 15, mode = "light") {
  type <- rlang::arg_match(type)
  p <- get_pair(cmp, pair)
  tab <- switch(by, zone = p$by_zone, height = p$by_height, area = p$by_area, grid = p$by_grid,
                cli::cli_abort("{.arg by} must be zone, height, area or grid."))
  if (is.null(tab)) cli::cli_abort("This comparison has no {by} summary; run {.fn compare_scenarios} with {.arg {by}}.")
  d <- as.data.frame(if (inherits(tab, "sf")) sf::st_drop_geometry(tab) else tab, stringsAsFactors = FALSE)
  key <- setdiff(names(d), grep(paste0("^(sites|land_area|", paste(measure_cols(), collapse = "|"), ")_"), names(d), value = TRUE))[1]
  b <- d[[paste0(measure, "_baseline")]]
  s <- d[[paste0(measure, "_scenario")]]
  ch <- s - b
  keep <- order(-abs(ch))[seq_len(min(top, nrow(d)))]
  if (type == "bars") keep <- keep[abs(ch[keep]) > 1e-9]
  d <- d[keep, , drop = FALSE]
  b <- b[keep]; s <- s[keep]; ch <- ch[keep]
  lv <- if (by == "height") rev(unique(as.character(d[[key]])[order(d[[key]])])) else as.character(d[[key]])[order(ch)]
  d$.g <- factor(as.character(d[[key]]), levels = if (by == "height") rev(lv) else lv)
  ink <- capacity_ink(mode)
  fmt <- measure_formatter(measure)
  dv <- capacity_palette("diverging", mode = mode)
  if (type == "dumbbell") {
    long <- rbind(data.frame(.g = d$.g, value = b, which = p$baseline),
                  data.frame(.g = d$.g, value = s, which = p$scenario))
    long$which <- factor(long$which, levels = c(p$baseline, p$scenario))
    out <- ggplot2::ggplot() +
      ggplot2::geom_segment(data = data.frame(.g = d$.g, b = b, s = s),
                            ggplot2::aes(x = .data$b, xend = .data$s, y = .data$.g, yend = .data$.g),
                            colour = ink$baseline, linewidth = 1.2) +
      ggplot2::geom_point(data = long, ggplot2::aes(x = .data$value, y = .data$.g, fill = .data$which),
                          shape = 21, size = 3.2, stroke = 0.9, colour = ink$surface) +
      ggplot2::scale_fill_manual(values = c(ink$secondary, capacity_palette("categorical", 1, mode = mode)),
                                 name = NULL) +
      ggplot2::geom_text(data = data.frame(.g = d$.g, x = pmax(b, s) + 0.025 * max(c(b, s), na.rm = TRUE),
                                           lab = label_signed(fmt)(ch)),
                         ggplot2::aes(x = .data$x, y = .data$.g, label = .data$lab), hjust = 0, size = 3,
                         colour = ink$secondary) +
      ggplot2::scale_x_continuous(labels = fmt, expand = ggplot2::expansion(mult = c(0.02, 0.15)))
  } else {
    out <- ggplot2::ggplot(data.frame(.g = d$.g, ch = ch), ggplot2::aes(x = .data$ch, y = .data$.g, fill = .data$ch > 0)) +
      ggplot2::geom_vline(xintercept = 0, colour = ink$baseline, linewidth = 0.4) +
      ggplot2::geom_col(width = 0.5) +
      ggplot2::scale_fill_manual(values = c(`TRUE` = dv[["gain"]], `FALSE` = dv[["loss"]]),
                                 labels = c(`TRUE` = "Gain", `FALSE` = "Loss"), name = NULL) +
      ggplot2::scale_x_continuous(labels = label_signed(fmt), expand = ggplot2::expansion(mult = 0.12))
  }
  out + ggplot2::labs(x = NULL, y = NULL, title = paste(measure_label(measure), "by", pretty_by(if (by == "height") "height_band" else by)),
                      subtitle = paste(p$baseline, "\u2192", p$scenario), caption = pair_caption(cmp)) +
    theme_capacity(mode = mode, grid = "x")
}

#' @rdname plot_comparison
#' @param on `"sites"` or `"grid"` (the comparison's grid).
#' @param basemap Whether to draw a basemap (see [plot_capacity_map()]).
#' @export
plot_change_map <- function(cmp, measure = "floor_area", on = c("sites", "grid"), pair = 1, mode = "light",
                            basemap = FALSE) {
  on <- rlang::arg_match(on)
  p <- get_pair(cmp, pair)
  d <- if (on == "grid") p$by_grid else p$sites
  if (is.null(d)) cli::cli_abort("This comparison has no grid; run {.fn compare_scenarios} with {.arg grid}.")
  d <- sf::st_as_sf(d)
  d$value <- d[[paste0(measure, "_change")]]
  ink <- capacity_ink(mode)
  lim <- max(abs(d$value), na.rm = TRUE)
  br <- signif(lim, 1) * c(-1, 0, 1)
  if (br[3] > lim) br <- signif(lim / 2, 1) * c(-1, 0, 1)
  fmt <- measure_formatter(measure)
  use_base <- !isFALSE(basemap)
  if (use_base) d <- sf::st_transform(d, 3857)
  ggplot2::ggplot(d) +
    (if (use_base) basemap_layer(d, basemap)) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data$value), colour = ink$surface, linewidth = if (on == "sites") 0.05 else 0.2,
                     alpha = if (use_base) 0.85 else 1) +
    scale_fill_capacity_div(mode = mode, limits = c(-lim, lim), breaks = br, labels = label_signed(fmt), name = NULL) +
    ggplot2::coord_sf(datum = NA, crs = sf::st_crs(d), expand = FALSE) +
    ggplot2::labs(title = paste("Change in", tolower(measure_label(measure))),
                  subtitle = paste(p$baseline, "\u2192", p$scenario, if (on == "grid") "(grid cells)" else "(sites)"),
                  caption = paste(pair_caption(cmp), if (use_base) basemap_credit(basemap))) +
    theme_capacity(mode = mode, grid = "none") +
    ggplot2::theme(axis.text = ggplot2::element_blank(), legend.key.width = ggplot2::unit(2.5, "lines"))
}

#' @rdname plot_comparison
#' @param changed_only Whether to leave out land that kept its zone.
#' @export
plot_transitions <- function(cmp, measure = "land_area", changed_only = FALSE, pair = 1, mode = "light") {
  p <- get_pair(cmp, pair)
  tr <- p$transitions
  col <- if (measure == "land_area") "land_area" else paste0(measure, "_change")
  tr <- tr[abs(tr$land_area) > 1, , drop = FALSE]
  if (changed_only) tr <- tr[tr$from != tr$to, , drop = FALSE]
  tr$value <- tr[[col]]
  zones <- unique(c(tr$from, tr$to))
  tr$from <- factor(tr$from, levels = rev(sort(unique(tr$from))))
  tr$to <- factor(tr$to, levels = sort(unique(tr$to)))
  ink <- capacity_ink(mode)
  fmt <- measure_formatter(if (measure == "land_area") "land_area" else measure)
  # Every tile is labelled, so the fill needs no legend.
  scale <- if (measure == "land_area") scale_fill_capacity_c(mode = mode, transform = "sqrt", guide = "none")
           else scale_fill_capacity_div(mode = mode, guide = "none")
  # Labels inside the tiles: white on a dark fill, ink on a light one.
  rng <- range(tr$value, na.rm = TRUE)
  dark <- if (measure == "land_area") sqrt(pmax(tr$value, 0)) > 0.55 * sqrt(max(rng[2], 1)) else abs(tr$value) > 0.55 * max(abs(rng))
  tr$ink <- ifelse(xor(dark, mode == "dark"), "#ffffff", ink$primary)
  if (mode == "dark") tr$ink <- ifelse(dark, ink$primary, "#ffffff")
  ggplot2::ggplot(tr, ggplot2::aes(x = .data$to, y = .data$from, fill = .data$value)) +
    ggplot2::geom_tile(colour = ink$surface, linewidth = 1.2) +
    ggplot2::geom_text(ggplot2::aes(label = if (measure == "land_area") fmt(.data$value) else label_signed(fmt)(.data$value),
                                    colour = .data$ink), size = 2.9) +
    ggplot2::scale_colour_identity() +
    scale +
    ggplot2::labs(x = paste("Zone in", p$scenario), y = paste("Zone in", p$baseline),
                  title = if (measure == "land_area") "Land by zone, before and after" else paste("Change in", tolower(measure_label(measure)), "by zone transition"),
                  subtitle = paste(p$baseline, "\u2192", p$scenario), caption = pair_caption(cmp)) +
    theme_capacity(mode = mode, grid = "none") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
}

#' @rdname plot_comparison
#' @param by_rule Whether to split the rules driver by rule, where the
#'   comparison has that split.
#' @export
plot_attribution <- function(cmp, measure = "floor_area", by_rule = FALSE, pair = 1, mode = "light") {
  p <- get_pair(cmp, pair)
  if (is.null(p$attribution) || !nrow(p$attribution)) cli::cli_abort("This comparison has no attribution.")
  a <- p$attribution
  steps <- a$driver
  vals <- a[[measure]]
  if (by_rule && !is.null(p$rule_attribution) && "rules" %in% steps) {
    r <- p$rule_attribution[abs(p$rule_attribution[[measure]]) > 1e-6, , drop = FALSE]
    i <- match("rules", steps)
    steps <- append(steps[-i], paste("Rules:", sub("^(zone|overlay|area|bonuse|entitlement)s\\.", "\\1 ", r$rule)), after = i - 1)
    vals <- append(vals[-i], r[[measure]], after = i - 1)
  }
  t <- p$totals
  base <- t$baseline[t$measure == measure]
  scen <- t$scenario[t$measure == measure]
  labs <- c(rules = "Rules", zoning = "Zoning", layers = "Overlay and area layers", parcels = "Parcels")
  lab <- ifelse(steps %in% names(labs), labs[steps], steps)
  waterfall(c("baseline", steps, "scenario"), c(base, vals, scen), first = "baseline", last = "scenario",
            labels = c(baseline = p$baseline, stats::setNames(lab, steps), scenario = p$scenario), mode = mode,
            fmt = measure_formatter(measure)) +
    ggplot2::labs(title = paste("What drove the change in", tolower(measure_label(measure))),
                  subtitle = paste0(p$baseline, " \u2192 ", p$scenario, ": each driver switched in turn (",
                                    if (identical(attr(p$attribution, "method"), "shapley")) "Shapley" else "sequential", ")"),
                  caption = pair_caption(cmp))
}

#' Plot a rule sweep
#'
#' @param sens A result of [sensitivity()].
#' @param measure The measure.
#' @param mode `"light"` or `"dark"`.
#' @return A ggplot object.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' s <- sensitivity(sc, "zones.MDR.ratios.coverage_max.value", c(0.3, 0.4, 0.5, 0.6))
#' plot_sensitivity(s)
plot_sensitivity <- function(sens, measure = "floor_area", mode = "light") {
  if (!inherits(sens, "plancap_sensitivity")) cli::cli_abort("{.arg sens} must come from {.fn sensitivity}.")
  d <- as.data.frame(unclass(sens), stringsAsFactors = FALSE)
  keys <- attr(sens, "by")
  ink <- capacity_ink(mode)
  fmt <- measure_formatter(measure)
  d$value <- if (is.numeric(d$value)) d$value else factor(d$value, levels = unique(d$value))
  if (length(keys)) {
    d$.g <- stable_levels(fold_other(d[[keys[1]]], abs(d[[measure]]), k = 8), NULL, NULL)
    d <- stats::aggregate(d[measure], by = d[c("value", ".g")], FUN = sum)
    last <- d[d$value == max(d$value), , drop = FALSE]
    p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$value, y = .data[[measure]], colour = .data$.g, group = .data$.g)) +
      ggplot2::geom_line(linewidth = 0.8) +
      ggplot2::geom_point(size = 2.6, stroke = 0.8, fill = NA) +
      scale_colour_capacity_d(mode = mode, name = NULL)
  } else {
    p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$value, y = .data[[measure]], group = 1)) +
      ggplot2::geom_line(colour = capacity_palette("categorical", 1, mode = mode), linewidth = 0.8) +
      ggplot2::geom_point(colour = capacity_palette("categorical", 1, mode = mode), size = 2.8) +
      ggplot2::geom_text(ggplot2::aes(label = fmt(.data[[measure]])), vjust = -1, size = 3, colour = ink$secondary)
  }
  p + ggplot2::scale_y_continuous(labels = fmt, expand = ggplot2::expansion(mult = c(0.05, 0.15))) +
    ggplot2::labs(x = attr(sens, "rule"), y = NULL, title = paste(measure_label(measure), "as the rule changes"),
                  subtitle = attr(sens, "scenario")) +
    theme_capacity(mode = mode, grid = "y")
}

#' Plot one site's envelope
#'
#' The site with its boundaries coloured by class and its storey footprints:
#' in plan (`view = "plan"`), the footprints shaded from the ground storey
#' (light) to the top (dark); or as an axonometric stack (`view = "axo"`),
#' each storey's footprint drawn at its height.
#'
#' @param cap A capacity result from [estimate_capacity()].
#' @param site_id The site.
#' @param view `"plan"` or `"axo"`.
#' @param mode `"light"` or `"dark"`.
#' @return A ggplot object.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' cap <- estimate_capacity(sc)
#' plot_site(cap, "P00001")
#' plot_site(cap, "P00001", view = "axo")
plot_site <- function(cap, site_id, view = c("plan", "axo"), mode = "light") {
  view <- rlang::arg_match(view)
  check_capacity_object(cap)
  x <- cap$inputs
  if (is.null(x)) cli::cli_abort("This capacity result does not carry its scenario; rerun {.fn estimate_capacity}.")
  s <- sf::st_drop_geometry(cap$sites)
  if (!site_id %in% s$site_id) cli::cli_abort("No site {.val {site_id}} in this result.")
  opts <- cap$options[intersect(names(cap$options), c("variant_choice", "max_storeys"))]
  env <- do.call(build_envelopes, c(list(x, include_density = TRUE, keep_geometry = TRUE, .only = site_id), opts))
  geo <- env$geometry[env$geometry$site_id == site_id, ]
  prep <- prepare_sites(x)
  site <- prep$sites[prep$sites$site_id == site_id, ]
  seg <- prep$segments[prep$segments$site_id == site_id, ]
  row <- s[s$site_id == site_id, ]
  # Only storeys with enabled area (the stack after caps).
  st <- cap$stack[cap$stack$site_id == site_id, ]
  geo <- geo[geo$storey %in% st$storey, ]
  ink <- capacity_ink(mode)
  cls <- c(road = capacity_palette("categorical", 1, mode = mode)[1],
           side = capacity_palette("categorical", 2, mode = mode)[2],
           rear = capacity_palette("categorical", 3, mode = mode)[3])
  n <- max(c(geo$storey, 1))
  shades <- capacity_palette("sequential", max(n, 2), mode = mode)[seq_len(n)]
  title <- paste0("Site ", site_id, ": ", row$zone_key %||% "no zone", ", ", label_area(row$floor_area), " in ",
                  row$storeys, " storey", if (row$storeys == 1) "" else "s")
  sub <- paste0(label_area(row$area), " site; ", row$dwellings, " dwelling", if (row$dwellings == 1) "" else "s",
                "; footprints are the area each storey may cover before caps such as coverage")
  if (view == "plan") {
    geo$storey_f <- factor(geo$storey)
    p <- ggplot2::ggplot() +
      ggplot2::geom_sf(data = site, fill = ink$neutral, colour = NA) +
      ggplot2::geom_sf(data = geo, ggplot2::aes(fill = .data$storey_f), colour = ink$surface, linewidth = 0.3) +
      ggplot2::scale_fill_manual(values = stats::setNames(shades, seq_len(n)), name = "Storey") +
      ggplot2::geom_sf(data = seg, ggplot2::aes(colour = .data$boundary_class), linewidth = 1.1) +
      ggplot2::scale_colour_manual(values = cls, name = "Boundary") +
      landscape_coord(sf::st_bbox(site))
  } else {
    # Axonometric: x' = x - y, y' = (x + y) / 2 + z, about the site's centre.
    cc <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(site)))[1, ]
    lev <- st$floor_level[match(geo$storey, st$storey)]
    proj <- function(g, z) {
      xy <- sf::st_coordinates(g)
      data.frame(x = (xy[, "X"] - cc[1]) - (xy[, "Y"] - cc[2]),
                 y = ((xy[, "X"] - cc[1]) + (xy[, "Y"] - cc[2])) / 2 + z,
                 id = interaction(xy[, setdiff(colnames(xy), c("X", "Y"))], drop = TRUE))
    }
    ground <- proj(sf::st_geometry(site), 0)
    plates <- do.call(rbind, lapply(seq_len(nrow(geo)), function(i) {
      q <- proj(sf::st_geometry(geo)[i], lev[i])
      q$storey <- geo$storey[i]
      q$id <- paste(i, q$id)
      q
    }))
    plates$storey_f <- factor(plates$storey)
    p <- ggplot2::ggplot() +
      ggplot2::geom_polygon(data = ground, ggplot2::aes(.data$x, .data$y, group = .data$id), fill = ink$neutral,
                            colour = ink$baseline, linewidth = 0.3)
    for (k in sort(unique(plates$storey))) {
      p <- p + ggplot2::geom_polygon(data = plates[plates$storey == k, ],
                                     ggplot2::aes(.data$x, .data$y, group = .data$id, fill = .data$storey_f),
                                     colour = ink$surface, linewidth = 0.4)
    }
    rx <- range(c(ground$x, plates$x))
    ry <- range(c(ground$y, plates$y))
    p <- p + ggplot2::scale_fill_manual(values = stats::setNames(shades, seq_len(n)), name = "Storey") +
      landscape_coord(c(xmin = rx[1], ymin = ry[1], xmax = rx[2], ymax = ry[2]), sf = FALSE)
    sub <- paste0(sub, "; axonometric, storeys at their floor levels (heights to scale)")
  }
  p + ggplot2::labs(title = title, subtitle = wrap_text(sub, 70), x = NULL, y = NULL,
                    caption = wrap_text(plot_caption(cap$conversion), 80)) +
    theme_capacity(mode = mode, grid = "none") +
    ggplot2::theme(axis.text = ggplot2::element_blank())
}

#' A capacity dashboard
#'
#' Four plots of a capacity result on one page: floor area by zone, by
#' storey, the constraint waterfall and a map. Needs the patchwork package.
#'
#' @param object A capacity result from [estimate_capacity()].
#' @param grid Cell size (m) for the map; default about a twentieth of the
#'   extent.
#' @param mode `"light"` or `"dark"`.
#' @param ... Unused.
#' @return A patchwork object.
#' @export
autoplot.plancap_capacity <- function(object, grid = NULL, mode = "light", ...) {
  rlang::check_installed("patchwork", reason = "to lay out the dashboard.")
  if (is.null(grid)) {
    bb <- sf::st_bbox(object$sites)
    grid <- signif(max(bb[["xmax"]] - bb[["xmin"]], bb[["ymax"]] - bb[["ymin"]]) / 20, 1)
  }
  strip <- ggplot2::theme(plot.caption = ggplot2::element_blank())
  a <- plot_capacity(object, mode = mode) + ggplot2::labs(subtitle = NULL) + strip
  b <- plot_height_profile(object, mode = mode) + ggplot2::labs(subtitle = NULL) + strip
  c <- plot_constraints(object, mode = mode) + ggplot2::labs(subtitle = NULL) + strip
  d <- plot_capacity_map(object, grid = grid, mode = mode) + ggplot2::labs(subtitle = NULL) + strip
  ink <- capacity_ink(mode)
  patchwork::wrap_plots(list(a, b, c, d), ncol = 2) +
    patchwork::plot_annotation(title = paste("Plan-enabled capacity:", object$scenario),
                               caption = plot_caption(object$conversion),
                               theme = theme_capacity(mode = mode))
}

# Equal-scale coordinates over an extent widened (or heightened) to at least
# a 4:3 landscape, centred, so a narrow site or plot fills the page.
landscape_coord <- function(bb, sf = TRUE, ratio = 4 / 3) {
  x <- c(bb[["xmin"]], bb[["xmax"]])
  y <- c(bb[["ymin"]], bb[["ymax"]])
  w <- diff(x)
  h <- diff(y)
  if (w < ratio * h) x <- mean(x) + c(-1, 1) * ratio * h / 2
  else if (w > 2.2 * h) y <- mean(y) + c(-1, 1) * w / 2.2 / 2
  pad <- 0.04 * max(diff(x), diff(y))
  if (sf) ggplot2::coord_sf(xlim = x + c(-pad, pad), ylim = y + c(-pad, pad), expand = FALSE, datum = NA)
  else ggplot2::coord_equal(xlim = x + c(-pad, pad), ylim = y + c(-pad, pad), expand = FALSE)
}
