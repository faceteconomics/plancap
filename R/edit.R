#' Change rules for a what-if or a scenario
#'
#' `set_rule()` changes one value by its path in the rulebook, for quick
#' what-if tests. `extend_rulebook()` applies a set of changes at once, the
#' same way a rulebook file with `extends:` does (see [read_rulebook()]).
#'
#' Paths are dot-separated names, with `[n]` for the n-th element of a list
#' (counting from 1), e.g. `"zones.MRZ.height.value"` or
#' `"zones.MRZ.setbacks[3].start_height"`.
#'
#' @param rb A `plancap_rulebook`.
#' @param path Path to the value.
#' @param value New value. `NULL` removes the entry.
#' @param validate If `TRUE`, check the result and stop on errors.
#' @return The changed rulebook.
#' @export
#' @examples
#' rb <- rulebook("Exampleton") |>
#'   add_zone(zone("MRZ", height = height_limit(11, source = "MRZ-S1"),
#'                 setbacks = list(yard(1, "side"), plane(60, 4, c("side", "rear")))))
#' rb2 <- set_rule(rb, "zones.MRZ.height.value", 16)
#' rb2 <- set_rule(rb2, "zones.MRZ.setbacks[2].start_height", 6)
#' rule_table(rb2)[, c("rule", "value")]
#'
#' rb3 <- extend_rulebook(rb, list(zones = list(MRZ = list(
#'   ratios = list(coverage_max = list(value = 0.5, source = "PC1"))))))
#' rb3$zones$MRZ$ratios
set_rule <- function(rb, path, value, validate = TRUE) {
  check_rulebook(rb)
  check_string(path, null_ok = FALSE)
  keys <- parse_rule_path(path)
  x <- to_plain(rb)
  x <- set_in(x, keys, if (is.list(value) || is.null(value)) to_plain(value) else value, path)
  out <- normalise_rulebook(x)
  if (validate) report_validation(validate_rulebook(out), "changed rulebook")
  out
}

#' @rdname set_rule
#' @param changes A named list in the rulebook's structure (or a rulebook)
#'   whose entries override `rb`.
#' @export
extend_rulebook <- function(rb, changes, validate = TRUE) {
  check_rulebook(rb)
  if (!is.list(changes)) cli::cli_abort("{.arg changes} must be a list.")
  out <- normalise_rulebook(merge_lists(to_plain(rb), to_plain(changes)))
  if (validate) report_validation(validate_rulebook(out), "extended rulebook")
  out
}

parse_rule_path <- function(path) {
  parts <- strsplit(path, ".", fixed = TRUE)[[1]]
  keys <- list()
  for (p in parts) {
    m <- regmatches(p, regexec("^([^\\[]+)((\\[[0-9]+\\])*)$", p))[[1]]
    if (!length(m)) cli::cli_abort("Cannot read path component {.val {p}}.")
    keys[[length(keys) + 1]] <- m[2]
    idx <- regmatches(m[3], gregexpr("[0-9]+", m[3]))[[1]]
    for (i in idx) keys[[length(keys) + 1]] <- as.integer(i)
  }
  keys
}

set_in <- function(x, keys, value, path) {
  k <- keys[[1]]
  if (length(keys) == 1) {
    if (is.numeric(k) && k > length(x) + 1) cli::cli_abort("Index {k} is out of range in {.val {path}}.")
    if (is.null(value)) {
      x[[k]] <- NULL
    } else {
      x[k] <- list(value)
    }
    return(x)
  }
  child <- if (is.numeric(k)) {
    if (k > length(x)) cli::cli_abort("Index {k} is out of range in {.val {path}}.")
    x[[k]]
  } else {
    x[[k]] %||% list()
  }
  x[[k]] <- set_in(child, keys[-1], value, path)
  x
}
