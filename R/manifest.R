#' Read a set of scenarios from a manifest file
#'
#' A manifest describes every scenario of a comparison in one YAML file, so
#' the comparison is reproducible from files alone. Each scenario has a
#' `name`, and either all of its inputs or `changes:` naming an earlier
#' scenario and only the inputs that differ (layers are merged by name, as in
#' [scenario_change()]). The first scenario is the baseline.
#'
#' ```yaml
#' scenarios:
#'   - name: Operative
#'     rulebook: example:exampleton            # or a path to a rulebook file
#'     parcels: {path: exampleton.gpkg, layer: parcels, filter: {parcel_type: land}}
#'     roads: {path: exampleton.gpkg, layer: parcels, filter: {parcel_type: road}}
#'     zoning: {path: exampleton.gpkg, layer: zoning}
#'     layers:
#'       height_areas: {path: exampleton.gpkg, layer: height_areas}
#'   - name: PC1
#'     changes: Operative
#'     rulebook: example:exampleton_pc1
#'     zoning: {path: exampleton_pc1.gpkg, layer: zoning}
#' ```
#'
#' A layer is a path to a file `sf` can read, or a list with `path`, an
#' optional `layer` and an optional `filter` (column to allowed values).
#' Paths are relative to the manifest. Other scenario arguments (such as
#' `zone_field`, `site_id`, `group_by`, `street_field`, `landholding`) are
#' given by name.
#'
#' @param path The manifest file.
#' @return A [scenario_set()].
#' @export
#' @examples
#' set <- read_scenarios(system.file("extdata", "exampleton_pc1_scenarios.yaml", package = "plancap"))
#' set
read_scenarios <- function(path) {
  check_string(path, null_ok = FALSE)
  if (!file.exists(path)) cli::cli_abort("File {.file {path}} does not exist.")
  m <- yaml::read_yaml(path, eval.expr = FALSE)
  if (is.null(m$scenarios) || !length(m$scenarios)) cli::cli_abort("{.file {path}} has no {.field scenarios}.")
  dir <- dirname(path)
  cache <- new.env(parent = emptyenv())
  read_layer <- function(spec) {
    if (is.null(spec)) return(NULL)
    if (is.character(spec)) spec <- list(path = spec)
    f <- spec$path
    if (!file.exists(f)) f <- file.path(dir, spec$path)
    if (!file.exists(f)) cli::cli_abort("Layer file {.file {spec$path}} not found.")
    key <- paste(normalizePath(f), spec$layer %||% "")
    x <- cache[[key]]
    if (is.null(x)) {
      x <- if (is.null(spec$layer)) sf::st_read(f, quiet = TRUE, stringsAsFactors = FALSE) else
        sf::st_read(f, layer = spec$layer, quiet = TRUE, stringsAsFactors = FALSE)
      assign(key, x, envir = cache)
    }
    for (col in names(spec$filter)) x <- x[as.character(x[[col]]) %in% as.character(unlist(spec$filter[[col]])), ]
    x
  }
  read_rb <- function(r) {
    if (startsWith(r, "example:")) return(rulebook_example(sub("^example:", "", r)))
    f <- if (file.exists(r)) r else file.path(dir, r)
    read_rulebook(f)
  }
  layer_args <- c("parcels", "zoning", "roads", "water", "centrelines", "easements", "other_parcels",
                  "buildings", "streets", "neighbours")
  out <- list()
  for (s in m$scenarios) {
    if (is.null(s$name)) cli::cli_abort("Every scenario in {.file {path}} needs a {.field name}.")
    args <- list()
    if (!is.null(s$rulebook)) args$rulebook <- read_rb(s$rulebook)
    for (a in intersect(layer_args, names(s))) args[[a]] <- read_layer(s[[a]])
    if (!is.null(s$layers)) args$layers <- lapply(s$layers, read_layer)
    if (!is.null(s$dem)) {
      rlang::check_installed("terra", reason = "to read a DEM.")
      f <- if (file.exists(s$dem)) s$dem else file.path(dir, s$dem)
      args$dem <- terra::rast(f)
    }
    other <- setdiff(names(s), c("name", "changes", "rulebook", "layers", "dem", layer_args, "notes"))
    for (a in other) args[[a]] <- s[[a]]
    args$notes <- s$notes
    if (!is.null(s$changes)) {
      base <- out[[s$changes]]
      if (is.null(base)) cli::cli_abort("Scenario {.val {s$name}} changes {.val {s$changes}}, which comes later or does not exist.")
      out[[s$name]] <- do.call(scenario_change, c(list(base, s$name), args))
    } else {
      if (is.null(args$rulebook)) cli::cli_abort("Scenario {.val {s$name}} needs a {.field rulebook}.")
      out[[s$name]] <- do.call(scenario, c(list(s$name), args))
    }
  }
  do.call(scenario_set, unname(out))
}
