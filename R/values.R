#' Banded values and ratios
#'
#' Some rules change in steps with another quantity: building coverage that
#' falls as a site gets larger, plot ratio that depends on building height,
#' density reduced by slope. `bands()` holds such a rule; `ratio()` wraps a
#' share of site area (a single value, a formula or bands) with its source.
#'
#' Bands are closed on the right: a site of exactly 200 m2 falls in a band
#' with `upper = 200`. The last band's upper bound may be `Inf`.
#'
#' @param by What the bands are keyed on: `"site_area"` (m2), `"height"` (m,
#'   of the storey tested), `"storey"`, `"slope"` (per cent), `"road_width"`
#'   (m), `"distance"` (m) or `"site_depth"` (m).
#' @param upper Upper bound of each band, ascending.
#' @param value Value in each band. Numbers or formula strings.
#' @param source Citation.
#' @return `bands()` returns a list with class `plancap_bands`;
#'   `band_value()` a numeric vector.
#' @export
#' @examples
#' # Coverage that falls with site size
#' cov <- bands("site_area", upper = c(200, 300, 500, Inf),
#'              value = c(0.55, 0.45, 0.40, 0.35))
#' band_value(cov, c(150, 200, 450, 1000))
bands <- function(by = c("site_area", "height", "storey", "slope", "road_width",
                         "distance", "site_depth"),
                  upper, value, source = NULL) {
  by <- rlang::arg_match(by)
  if (!is.numeric(upper) || anyNA(upper) || is.unsorted(upper, strictly = TRUE)) {
    cli::cli_abort("{.arg upper} must be strictly ascending numbers.")
  }
  if (length(value) != length(upper)) {
    cli::cli_abort("{.arg value} must have one entry per band ({length(upper)}), not {length(value)}.")
  }
  value <- lapply(as.list(value), function(v) {
    # c(0.5, "max(...)") coerces numbers to text; turn them back.
    if (is_string(v) && !is.na(suppressWarnings(as.numeric(v)))) as.numeric(v) else v
  })
  for (v in value) check_value(v, arg = "value")
  lower <- c(0, utils::head(upper, -1))
  b <- lapply(seq_along(upper), function(i) {
    compact(list(min = lower[i], max = if (is.finite(upper[i])) upper[i],
                 value = value[[i]]))
  })
  structure(compact(list(by = by, bands = b, source = source)), class = "plancap_bands")
}

#' @rdname bands
#' @param x A `plancap_bands` object (or the equivalent list read from a file).
#' @param at Values of the `by` quantity to look up.
#' @param vars Variables for any formula values, see [eval_rule_value()].
#' @export
band_value <- function(x, at, vars = list()) {
  uppers <- vapply(x$bands, function(b) b[["max"]] %||% Inf, numeric(1))
  idx <- findInterval(at, uppers, left.open = TRUE) + 1
  idx[idx > length(uppers)] <- NA
  out <- rep(NA_real_, length(at))
  for (i in unique(stats::na.omit(idx))) {
    sel <- which(idx == i)
    v <- x$bands[[i]]$value
    sub <- lapply(vars, function(z) if (length(z) == length(at)) z[sel] else z)
    out[sel] <- rep_len(eval_rule_value(v, sub), length(sel))
  }
  out
}

#' A share of site area
#'
#' Wraps a coverage, landscaping, impervious or floor area ratio rule with its
#' citation.
#'
#' @param value A number (a share, so between 0 and 1 for coverage-type
#'   rules), a formula string, or [bands()].
#' @param source Citation.
#' @return A list with class `plancap_ratio`.
#' @export
#' @examples
#' ratio(0.5, source = "Rule 4.3.2")
#' ratio(bands("site_area", c(500, Inf), c(0.5, 0.4)), source = "Table 5")
ratio <- function(value, source = NULL) {
  if (inherits(value, "plancap_bands")) {
    return(structure(compact(list(bands = unclass(value), source = source)),
                     class = "plancap_ratio"))
  }
  check_value(value, null_ok = FALSE)
  if (is.numeric(value)) check_number(value, lower = 0, upper = 1)
  check_string(source)
  structure(compact(list(value = value, source = source)), class = "plancap_ratio")
}

# Value of a ratio (number, formula, bands, or a bare number from a file) at a
# set of sites/storeys. `key` supplies the banding quantities by name.
resolve_ratio <- function(r, vars = list()) {
  if (is.null(r)) return(NULL)
  if (is.numeric(r) || is.character(r)) return(eval_rule_value(r, vars))
  if (!is.null(r$bands)) {
    b <- r$bands
    at <- vars[[b$by]]
    if (is.null(at)) cli::cli_abort("Bands keyed on {.field {b$by}} need that value supplied.")
    return(band_value(b, at, vars))
  }
  eval_rule_value(r$value, vars)
}
