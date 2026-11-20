#' Check and draw how sites and boundaries were classified
#'
#' Before trusting a run on a new jurisdiction's cadastre, look at what the
#' morphology helpers made of it. `check_morphology()` compares the shares of
#' each class with ranges typical of suburban cadastres and says which look
#' wrong (a corner-site share near a quarter, for instance, once revealed that
#' curved frontages were being read as two). `plot_morphology()` draws the
#' classification for an area so it can be checked by eye.
#'
#' @param x Prepared sites from [prepare_sites()].
#' @return `check_morphology()`: a data frame of `measure`, `value`, the
#'   plausible range and a `status` of `"ok"` or `"check"`.
#' @export
#' @examples
#' town <- exampleton()
#' s <- prepare_sites(scenario("Operative", rulebook_example("exampleton"),
#'   parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'   roads = town$parcels[town$parcels$parcel_type == "road", ],
#'   zoning = town$zoning))
#' check_morphology(s)
#' plot_morphology(s, sites = c("P00180", "P00200"), pad = 60)
check_morphology <- function(x) {
  if (!inherits(x, "plancap_sites")) cli::cli_abort("{.arg x} must come from {.fn prepare_sites}.")
  s <- x$sites
  seg <- x$segments
  n <- nrow(s)
  rows <- list(
    c("sites with no road frontage", mean(s$frontage == 0), 0, 0.05),
    c("corner sites", mean(s$is_corner), 0.02, 0.25),
    c("through sites", mean(s$is_through), 0, 0.05),
    c("rear sites", mean(s$is_rear), 0, 0.30),
    c("rear sites with an access leg", if (any(s$is_rear)) mean(s$access_leg_area[s$is_rear] > 0) else NA, 0.3, 1),
    c("boundary length that is road frontage", sum(seg$length[seg$boundary_class == "road"]) / sum(seg$length), 0.15, 0.45),
    c("boundary length that is rear", sum(seg$length[seg$boundary_class == "rear"]) / sum(seg$length), 0.1, 0.35),
    c("boundaries with no zone across", mean(is.na(seg$adjacent_zone_key)), 0, 0.05),
    c("sites with no zone", mean(is.na(s$zone_key)), 0, 0.01),
    c("sites split by a zone boundary", (x$report$sites_split %||% 0) / n, 0, 0.05)
  )
  df <- data.frame(measure = vapply(rows, `[[`, "", 1),
                   value = as.numeric(vapply(rows, `[[`, "", 2)),
                   low = as.numeric(vapply(rows, `[[`, "", 3)),
                   high = as.numeric(vapply(rows, `[[`, "", 4)),
                   stringsAsFactors = FALSE)
  df$status <- ifelse(is.na(df$value), "n/a",
                      ifelse(df$value >= df$low & df$value <= df$high, "ok", "check"))
  class(df) <- c("plancap_morphology_check", class(df))
  df
}

#' @export
print.plancap_morphology_check <- function(x, ...) {
  cli::cli_text("{.strong Morphology check}: {sum(x$status == 'check')} measure{?s} outside the usual range.")
  out <- data.frame(measure = x$measure,
                    value = sprintf("%.1f%%", 100 * x$value),
                    usual = sprintf("%g-%g%%", 100 * x$low, 100 * x$high),
                    status = x$status)
  print(out, row.names = FALSE, right = FALSE)
  invisible(x)
}

#' @rdname check_morphology
#' @param sites Optional site ids to centre the view on.
#' @param area Optional `sf` object or bounding box to draw; defaults to the
#'   `sites` given, or everything.
#' @param pad Margin (m) around `sites` or `area`.
#' @return `plot_morphology()`: a `ggplot`.
#' @export
plot_morphology <- function(x, sites = NULL, area = NULL, pad = 30) {
  if (!inherits(x, "plancap_sites")) cli::cli_abort("{.arg x} must come from {.fn prepare_sites}.")
  s <- x$sites
  seg <- x$segments
  bb <- if (!is.null(area)) sf::st_bbox(area) else if (!is.null(sites)) {
    sf::st_bbox(s[s$site_id %in% sites | s$parent_id %in% sites, ])
  } else sf::st_bbox(s)
  bb <- bb + c(-pad, -pad, pad, pad)
  box <- sf::st_as_sfc(bb)
  keep_s <- lengths(sf::st_intersects(s, box)) > 0
  keep_g <- lengths(sf::st_intersects(seg, box)) > 0
  s <- s[keep_s, ]
  seg <- seg[keep_g, ]
  seg$what <- seg$boundary_class
  for (t in c("reserve", "riparian", "coastal", "lakeside", "zone_boundary")) {
    seg$what[grepl(paste0("|", t, "|"), seg$tags, fixed = TRUE)] <- t
  }
  s$type <- ifelse(s$is_through, "through", ifelse(s$is_corner, "corner",
                   ifelse(s$is_rear, "rear", "ordinary")))
  legs <- x$access_legs[x$access_legs$site_id %in% s$site_id, ]
  pal <- c(road = "#1f4e79", side = "#9aa5b1", rear = "#c0504d", reserve = "#3a9d5d",
           riparian = "#00a6a6", coastal = "#00a6a6", lakeside = "#00a6a6",
           zone_boundary = "#e39b2d")
  fill <- c(ordinary = "#f4f1ea", corner = "#e6eef7", through = "#efe6f7", rear = "#f7e9e6")
  ggplot2::ggplot() +
    ggplot2::geom_sf(data = s, ggplot2::aes(fill = .data$type), colour = NA) +
    ggplot2::geom_sf(data = legs, fill = "#c0504d", alpha = 0.25, colour = NA) +
    ggplot2::geom_sf(data = seg, ggplot2::aes(colour = .data$what), linewidth = 0.7) +
    ggplot2::scale_fill_manual(values = fill, name = "Site") +
    ggplot2::scale_colour_manual(values = pal, name = "Boundary") +
    ggplot2::coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")],
                      datum = NA, expand = FALSE) +
    ggplot2::labs(caption = "Shaded strips are access legs.") +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "right")
}
