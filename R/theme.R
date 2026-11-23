#' The plancap plot theme and colour scales
#'
#' Every plancap plot uses one quiet theme, so the data is the only loud
#' thing on the page: a plain surface, hairline gridlines along the value
#' axis only, and text in three inks (primary, secondary, muted), never in a
#' series colour. `mode = "dark"` gives the same theme on a dark surface,
#' with colours stepped for it rather than inverted.
#'
#' Colour has one job per scale:
#'
#' - **categorical** (identity): eight hues in a fixed order, validated for
#'   colour vision deficiency between neighbours in both modes. Slots are
#'   never cycled: a ninth category is folded into "Other" (see
#'   [capacity_palette()]);
#' - **sequential** (magnitude): one hue, blue, light to dark (on the dark
#'   surface, dark to light, so small values recede);
#' - **diverging** (gain or loss): blue for a gain and red for a loss, either
#'   side of a grey midpoint.
#'
#' @param mode `"light"` or `"dark"`.
#' @param base_size Base font size (pt).
#' @param base_family Font family; default the system sans.
#' @param grid Which gridlines: `"x"`, `"y"`, `"both"` or `"none"`.
#' @return `theme_capacity()`: a ggplot2 theme. The scale functions return
#'   ggplot2 scales.
#' @seealso [capacity_palette()]
#' @export
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_capacity()
theme_capacity <- function(mode = c("light", "dark"), base_size = 11, base_family = "", grid = "y") {
  mode <- rlang::arg_match(mode)
  ink <- capacity_ink(mode)
  gl <- ggplot2::element_line(colour = ink$grid, linewidth = 0.3)
  blank <- ggplot2::element_blank()
  t <- ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = ink$surface, colour = NA),
      panel.background = ggplot2::element_rect(fill = ink$surface, colour = NA),
      text = ggplot2::element_text(colour = ink$primary),
      plot.title = ggplot2::element_text(face = "bold", size = base_size * 1.2, colour = ink$primary,
                                         margin = ggplot2::margin(b = 4)),
      plot.subtitle = ggplot2::element_text(colour = ink$secondary, margin = ggplot2::margin(b = 10)),
      plot.caption = ggplot2::element_text(colour = ink$muted, size = base_size * 0.8, hjust = 0,
                                           margin = ggplot2::margin(t = 10)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.text = ggplot2::element_text(colour = ink$muted),
      axis.title = ggplot2::element_text(colour = ink$secondary, size = base_size * 0.9),
      axis.ticks = blank,
      panel.grid.minor = blank,
      panel.grid.major.x = if (grid %in% c("x", "both")) gl else blank,
      panel.grid.major.y = if (grid %in% c("y", "both")) gl else blank,
      legend.position = "top",
      legend.justification = "left",
      legend.location = "plot",
      legend.title = ggplot2::element_text(colour = ink$secondary, size = base_size * 0.9),
      legend.text = ggplot2::element_text(colour = ink$secondary),
      legend.key.size = ggplot2::unit(0.8, "lines"),
      strip.text = ggplot2::element_text(colour = ink$primary, face = "bold", hjust = 0),
      plot.margin = ggplot2::margin(12, 14, 10, 12)
    )
  t
}

# Surfaces and inks, light and dark.
capacity_ink <- function(mode = "light") {
  if (identical(mode, "dark")) {
    list(surface = "#1a1a19", primary = "#f0efec", secondary = "#c3c2b7", muted = "#898781",
         grid = "#2c2c2a", baseline = "#383835", neutral = "#383835", reference = "#6f6e69")
  } else {
    list(surface = "#fcfcfb", primary = "#0b0b0b", secondary = "#52514e", muted = "#898781",
         grid = "#e1e0d9", baseline = "#c3c2b7", neutral = "#f0efec", reference = "#b8b7b0")
  }
}

#' Colours of the plancap palette
#'
#' @param type `"categorical"`, `"sequential"`, `"diverging"` or `"ink"`.
#' @param n For categorical, how many slots (at most 8); for sequential, how
#'   many steps.
#' @param mode `"light"` or `"dark"`.
#' @return A character vector of hex colours (`"ink"`: a named list).
#' @export
#' @examples
#' capacity_palette("categorical", 4)
#' capacity_palette("sequential", 5, mode = "dark")
capacity_palette <- function(type = c("categorical", "sequential", "diverging", "ink"), n = NULL,
                             mode = c("light", "dark")) {
  type <- rlang::arg_match(type)
  mode <- rlang::arg_match(mode)
  switch(type,
    categorical = {
      cols <- if (mode == "light") c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948")
              else c("#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#0ca30c", "#9085e9", "#e66767")
      n <- n %||% 8
      if (n > 8) cli::cli_abort(c("The categorical palette has eight slots; {n} were asked for.",
                                  "i" = "Fold the smaller categories into \"Other\" or use small multiples."))
      cols[seq_len(n)]
    },
    sequential = {
      ramp <- c("#cde2fb", "#b7d3f6", "#9ec5f4", "#86b6ef", "#6da7ec", "#5598e7", "#3987e5", "#2a78d6",
                "#256abf", "#1c5cab", "#184f95", "#104281", "#0d366b")
      if (mode == "dark") ramp <- rev(ramp)
      if (is.null(n)) ramp else grDevices::colorRampPalette(ramp)(n)
    },
    diverging = {
      if (mode == "light") c(loss = "#e34948", mid = "#f0efec", gain = "#2a78d6")
      else c(loss = "#e66767", mid = "#383835", gain = "#3987e5")
    },
    ink = capacity_ink(mode)
  )
}

#' @rdname theme_capacity
#' @param ... Passed to the ggplot2 scale.
#' @export
scale_fill_capacity_d <- function(..., mode = "light") {
  ggplot2::discrete_scale("fill", palette = function(n) capacity_palette("categorical", n, mode = mode), ...)
}

#' @rdname theme_capacity
#' @export
scale_colour_capacity_d <- function(..., mode = "light") {
  ggplot2::discrete_scale("colour", palette = function(n) capacity_palette("categorical", n, mode = mode), ...)
}

#' @rdname theme_capacity
#' @export
scale_fill_capacity_c <- function(..., mode = "light") {
  ggplot2::scale_fill_gradientn(colours = capacity_palette("sequential", mode = mode), ...)
}

#' @rdname theme_capacity
#' @param midpoint Value at the grey midpoint of the diverging scale.
#' @export
scale_fill_capacity_div <- function(..., midpoint = 0, mode = "light") {
  d <- capacity_palette("diverging", mode = mode)
  ggplot2::scale_fill_gradient2(low = d[["loss"]], mid = d[["mid"]], high = d[["gain"]], midpoint = midpoint, ...)
}

# ---- Labels --------------------------------------------------------------------

# Floor area, land and counts: in full under 10,000, then compact (12.9K,
# 4.2M); areas carry m2.
label_area <- function(x) paste0(label_count(x), " m\u00b2")
label_count <- function(x) {
  # One style for the whole set (an axis, a column of labels): in full when
  # every value is under 10,000, otherwise compact.
  compact <- any(abs(x) >= 10000, na.rm = TRUE)
  one <- function(v) {
    if (is.na(v)) return(NA_character_)
    a <- abs(v)
    out <- if (!compact || a < 1000) formatC(round(v), format = "d", big.mark = ",")
           else if (a < 1e6) paste0(formatC(v / 1e3, format = "f", digits = if (a < 1e5) 1 else 0), "K")
           else paste0(formatC(v / 1e6, format = "f", digits = 1), "M")
    sub("\\.0([KM])$", "\\1", out)
  }
  vapply(x, one, "")
}
label_signed <- function(f) function(x) ifelse(!is.na(x) & x > 0, paste0("+", f(x)), f(x))

measure_label <- function(m) {
  c(floor_area = "Floor area", residential_floor_area = "Residential floor area",
    business_floor_area = "Business floor area", dwellings = "Dwellings", land_area = "Land",
    sites = "Sites", minor_dwellings = "Minor dwellings", floor_area_per_ha = "Floor area per hectare",
    dwellings_per_ha = "Dwellings per hectare", far = "Floor area ratio")[[m]] %||% m
}
measure_formatter <- function(m) {
  if (m %in% c("floor_area", "residential_floor_area", "business_floor_area", "land_area", "floor_area_per_ha",
               "floor_area_with_bonus")) label_area
  else if (m == "far") function(x) formatC(x, format = "f", digits = 2)
  else label_count
}

# The note every capacity plot carries.
plot_caption <- function(conv, extra = NULL) {
  gsub(" m2", " m\u00b2", paste(c(extra, conversion_note(conv)), collapse = " "))
}

# Subtitles wrapped, so a narrow plot (a map, a square) does not clip them.
wrap_text <- function(x, width = 80) paste(strwrap(x, width = width), collapse = "\n")

# Categories in a stable order: zones in the rulebook's order, so a zone
# keeps its colour from plot to plot; "Other" last.
stable_levels <- function(f, rb = NULL, by = NULL) {
  if (is.null(rb) || is.null(by) || !by %in% c("zone", "zone_key")) return(f)
  lv <- levels(f)
  zo <- names(rb$zones)
  keep <- setdiff(lv, "Other")
  ord <- c(keep[order(match(keep, zo), keep)], intersect("Other", lv))
  factor(as.character(f), levels = ord)
}

# Keep the largest `k - 1` categories and fold the rest into "Other", so a
# categorical scale never runs out of slots.
fold_other <- function(x, weight, k = 8) {
  x <- as.character(x)
  x[is.na(x)] <- "(none)"
  tot <- sort(tapply(weight, x, sum, na.rm = TRUE), decreasing = TRUE)
  if (length(tot) <= k) return(factor(x, levels = names(tot)))
  keep <- names(tot)[seq_len(k - 1)]
  x[!x %in% keep] <- "Other"
  factor(x, levels = c(keep, "Other"))
}
