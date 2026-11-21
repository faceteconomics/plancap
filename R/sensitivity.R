#' Sweep a rule through a set of values
#'
#' Runs capacity with one rule set to each of `values` in turn and returns a
#' tidy table of the results, so the effect of a height limit, a recession
#' plane angle or a site area per dwelling can be read or plotted. Each run
#' after the first is incremental: only sites whose rules change are rebuilt.
#'
#' @param x A [scenario()].
#' @param rule Path of the rule to change, as for [set_rule()], such as
#'   `"zones.MDR.ratios.coverage_max.value"`. A height is several linked
#'   values (total, occupiable, storeys); sweep it by giving whole
#'   `height_limit()`s as `values`, at path `"zones.MDR.height"`.
#' @param values The values to try: numbers, formulas as strings, or a list
#'   of whole rules (then `value` in the result is the position in the list).
#' @param by Optional grouping, as for [summarise_capacity()].
#' @param measures Measures, as for [summarise_capacity()].
#' @param ... Passed to [estimate_capacity()].
#' @return A data frame of class `plancap_sensitivity`: `value`, the grouping
#'   columns, the measures, and `floor_area_change` and `dwellings_change`
#'   against the first value where those measures are asked for.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' sensitivity(sc, "zones.MDR.ratios.coverage_max.value", c(0.4, 0.5, 0.6), by = "zone")
sensitivity <- function(x, rule, values, by = NULL, measures = c("floor_area", "dwellings"), ...) {
  if (!inherits(x, "plancap_scenario")) cli::cli_abort("{.arg x} must be a {.fn scenario}.")
  check_string(rule, null_ok = FALSE)
  if (!length(values)) cli::cli_abort("{.arg values} must have at least one value.")
  base <- NULL
  rows <- vector("list", length(values))
  for (i in seq_along(values)) {
    v <- if (is.list(values)) values[[i]] else values[i]
    scalar <- is.atomic(v) && length(v) == 1
    rb <- set_rule(x$rulebook, rule, v)
    sc <- scenario_change(x, paste0(x$name, ": ", rule, " = ", if (scalar) format(v) else paste("value", i)),
                          rulebook = rb)
    cap <- estimate_capacity(sc, baseline = base, ...)
    if (is.null(base)) base <- cap
    sm <- summarise_capacity(cap, by = by, measures = measures)
    df <- as.data.frame(unclass(if (inherits(sm, "sf")) sf::st_drop_geometry(sm) else sm), stringsAsFactors = FALSE)
    # A whole rule (a list) is labelled by its position in `values`.
    df <- cbind(value = rep(if (!scalar) i else if (is.numeric(v)) v else as.character(v), nrow(df)), df)
    rows[[i]] <- df
  }
  out <- do.call(rbind, rows)
  keys <- by_columns(by)
  first <- out[out$value == out$value[1], , drop = FALSE]
  k <- if (length(keys)) match(do.call(paste, c(out[keys], sep = "\r")), do.call(paste, c(first[keys], sep = "\r")))
       else rep(1L, nrow(out))
  for (m in intersect(c("floor_area", "dwellings"), measures)) out[[paste0(m, "_change")]] <- out[[m]] - first[[m]][k]
  rownames(out) <- NULL
  attr(out, "rule") <- rule
  attr(out, "by") <- keys
  attr(out, "scenario") <- x$name
  class(out) <- c("plancap_sensitivity", "data.frame")
  out
}

#' @export
print.plancap_sensitivity <- function(x, ...) {
  cli::cli_text("{.strong <plancap sensitivity>} {attr(x, 'scenario')}: {.field {attr(x, 'rule')}}")
  print(format_summary(as.data.frame(unclass(x), stringsAsFactors = FALSE)), row.names = FALSE, right = TRUE)
  invisible(x)
}
