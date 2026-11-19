#' Read and write rulebooks
#'
#' Rulebooks are stored as YAML (`.yaml`, `.yml`), JSON (`.json`) or a
#' spreadsheet (`.xlsx`, see [rulebook_template()]). All three hold the same
#' structure, described by the JSON Schema returned by
#' [rulebook_schema_path()].
#'
#' A YAML or JSON rulebook may start with `extends: other.yaml` (a path
#' relative to the file). It is then read as a set of changes to that
#' rulebook: named entries replace or merge into the base, lists (such as a
#' zone's setbacks) replace the base's list whole, and an entry set to `null`
#' (`~` in YAML) is removed. This is how scenarios and plan changes are
#' written.
#'
#' @param path File path.
#' @param validate If `TRUE` (default), check the rulebook with
#'   [validate_rulebook()]. Errors stop reading; warnings are reported.
#' @return `read_rulebook()` returns a `plancap_rulebook`.
#'   `write_rulebook()` returns `path`, invisibly.
#' @export
#' @examples
#' rb <- rulebook("Exampleton District Plan") |>
#'   add_zone(zone("LDR", height = height_limit(8, source = "LDR-S1")))
#' f <- tempfile(fileext = ".yaml")
#' write_rulebook(rb, f)
#' identical(read_rulebook(f)$zones, rb$zones)
read_rulebook <- function(path, validate = TRUE) {
  check_string(path, null_ok = FALSE)
  if (!file.exists(path)) cli::cli_abort("File {.file {path}} does not exist.")
  ext <- tolower(tools::file_ext(path))
  x <- switch(ext,
    yaml = , yml = yaml::read_yaml(path, eval.expr = FALSE),
    json = jsonlite::fromJSON(path, simplifyVector = FALSE),
    xlsx = return(read_rulebook_xlsx(path, validate = validate)),
    cli::cli_abort("Unsupported rulebook file type {.val {ext}}; use .yaml, .json or .xlsx.")
  )
  if (!is.null(x$extends)) {
    base_path <- x$extends
    if (!file.exists(base_path)) base_path <- file.path(dirname(path), x$extends)
    base <- read_rulebook(base_path, validate = FALSE)
    x$extends <- NULL
    x <- merge_lists(to_plain(base), x)
  }
  rb <- normalise_rulebook(x)
  if (validate) report_validation(validate_rulebook(rb), path)
  rb
}

#' @rdname read_rulebook
#' @param rb A `plancap_rulebook`.
#' @param units Optionally convert to `"m"` or `"ft"` before writing.
#' @export
write_rulebook <- function(rb, path, units = NULL) {
  check_rulebook(rb)
  check_string(path, null_ok = FALSE)
  if (!is.null(units)) rb <- convert_rulebook_units(rb, units)
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    yaml = , yml = {
      txt <- yaml::as.yaml(to_plain(rb), indent.mapping.sequence = TRUE,
                           precision = 15)
      header <- paste0("# plancap rulebook (schema ", rulebook_schema_version(), ")\n",
                       "# ", rb$plan$name, "\n")
      writeLines(paste0(header, txt), path, useBytes = TRUE)
    },
    json = writeLines(rulebook_to_json(rb, pretty = TRUE), path, useBytes = TRUE),
    xlsx = write_rulebook_xlsx(rb, path),
    cli::cli_abort("Unsupported rulebook file type {.val {ext}}; use .yaml, .json or .xlsx.")
  )
  invisible(path)
}

#' Path to the rulebook JSON Schema
#'
#' @return Path to `rulebook.schema.json` in the installed package.
#' @export
#' @examples
#' basename(rulebook_schema_path())
rulebook_schema_path <- function() {
  system.file("schema", "rulebook.schema.json", package = "plancap", mustWork = TRUE)
}

# ---- Internal: plain structure, arrays and JSON ------------------------------

# Strip classes and attributes recursively, drop NULLs, and put keys in the
# schema's order so every route (R, YAML, JSON, XLSX) gives the same structure.
to_plain <- function(x, parent = "") {
  if (is.list(x)) {
    nms <- names(x)
    out <- lapply(seq_along(x), function(i) to_plain(x[[i]], if (is.null(nms)) parent else nms[i]))
    names(out) <- nms
    out <- out[!vapply(out, is.null, logical(1))]
    if (!is.null(names(out)) && !parent %in% map_keys) {
      ord <- schema_key_order()
      pos <- match(names(out), ord)
      if (!anyNA(pos)) out <- out[order(pos)]
    }
    return(out)
  }
  if (is.factor(x)) x <- as.character(x)
  if (inherits(x, "Date")) x <- format(x)
  if (is.integer(x)) x <- as.numeric(x)  # JSON and YAML readers return integers
  attributes(x) <- NULL
  x
}

# Keys whose children are user-named entries (zone keys, ids, codes), whose
# order is the user's.
map_keys <- c("zones", "overlays", "areas", "bonuses", "entitlements", "zone_map",
              "zone_families", "variants", "value_map", "filter", "zone_parameters",
              "sub_areas")

# Every property name in the schema, in order of first appearance.
schema_key_order <- function() {
  if (is.null(the$key_order)) {
    txt <- paste(readLines(rulebook_schema_path(), warn = FALSE), collapse = "\n")
    s <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
    keys <- character()
    walk <- function(node) {
      if (!is.list(node)) return()
      if (!is.null(node$properties) && is.list(node$properties)) {
        keys <<- c(keys, names(node$properties))
      }
      for (child in node) walk(child)
    }
    walk(s)
    head <- c("schema_version", "extends", "kind", "name", "label", "type", "method", "quantity")
    tail <- c("variant", "activity_status", "source", "notes")
    the$key_order <- unique(c(head, setdiff(keys, tail), tail))
  }
  the$key_order
}

# Keys whose value is always an array in the schema, so a single element read
# from YAML must not become a scalar.
array_keys <- c("boundaries", "applies_to_zones", "adjacent_zones", "not_adjacent_zones",
                "zones", "reserve_families", "setbacks", "facing", "unit_mix",
                "access_width", "angle_by_bearing", "points", "unmodelled_rules",
                "replaces_setbacks")
# Keys whose value is an object whose every child is an array.
array_parent_keys <- c("zone_families", "filter")
# Keys whose value must be an object even when empty.
object_keys <- c("zones", "overlays", "areas", "bonuses", "entitlements", "zone_map",
                 "zone_families", "variants", "value_map", "zone_parameters",
                 "sub_areas")

# Make the structure JSON-shaped: arrays where the schema has arrays, objects
# where it has objects. `key` is the name this value sits under; `depth` is 1
# for children of the root (where `zones` is the zone map, not an array).
json_shape <- function(x, key = "", depth = 0) {
  is_array_key <- key %in% array_keys && !(key == "zones" && depth == 1)
  if (is_array_key) {
    if (is.atomic(x)) return(as.list(x))
    out <- lapply(x, function(e) if (is.list(e)) json_shape(e, "", depth + 1) else e)
    names(out) <- NULL
    return(out)
  }
  if (key %in% array_parent_keys && is.list(x)) {
    out <- lapply(x, function(e) if (is.atomic(e)) as.list(e) else e)
    if (!length(out)) out <- structure(list(), names = character(0))
    return(out)
  }
  if (!is.list(x)) return(x)
  if (is.null(names(x))) {
    if (!length(x) && key %in% object_keys) return(structure(list(), names = character(0)))
    return(lapply(x, json_shape, key = "", depth = depth + 1))
  }
  for (nm in names(x)) {
    x[nm] <- list(json_shape(x[[nm]], nm, depth + 1))
  }
  x
}

rulebook_to_json <- function(rb, pretty = FALSE) {
  x <- to_plain(rb)
  if (is.null(x$zones) || !length(x$zones)) x$zones <- structure(list(), names = character(0))
  x <- json_shape(x)
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA, pretty = pretty)
}

# After reading from a file: restore R-side shapes (character vectors for
# string arrays) and the class.
normalise_rulebook <- function(x) {
  x <- to_plain(x)
  vecify <- function(y) {
    if (!is.list(y)) return(y)
    if (!is.null(names(y))) {
      for (nm in names(y)) {
        v <- y[[nm]]
        if (nm %in% c("boundaries", "applies_to_zones", "adjacent_zones",
                      "not_adjacent_zones", "zones", "reserve_families",
                      "replaces_setbacks") &&
            is.list(v) && all(vapply(v, is_string, logical(1)))) {
          y[[nm]] <- unlist(v)
        } else if (nm %in% array_parent_keys && is.list(v)) {
          y[[nm]] <- lapply(v, function(e) if (is.list(e)) unlist(e) else e)
        } else if (nm == "facing" && is.list(v)) {
          y[[nm]] <- unlist(v)
        } else if (nm == "points") {
          y[[nm]] <- lapply(v, function(p) as.numeric(unlist(p)))
        } else {
          y[[nm]] <- vecify(v)
        }
      }
      y
    } else {
      lapply(y, vecify)
    }
  }
  x <- vecify(x)
  if (is.null(x$zones)) x$zones <- list()
  new_rulebook(x)
}

# ---- Internal: validation ----------------------------------------------------

the <- new.env(parent = emptyenv())

schema_validator <- function() {
  if (is.null(the$validator)) {
    the$validator <- jsonvalidate::json_validator(rulebook_schema_path(), engine = "ajv")
  }
  the$validator
}

report_validation <- function(v, what = "rulebook", call = rlang::caller_env()) {
  iss <- v$issues
  err <- iss[iss$severity == "error", , drop = FALSE]
  if (nrow(err)) {
    msgs <- esc(utils::head(paste0(err$path, ": ", err$message), 20))
    cli::cli_abort(c("{.file {what}} has {nrow(err)} error{?s}:",
                     stats::setNames(msgs, rep("x", length(msgs)))), call = call)
  }
  warn <- iss[iss$severity == "warning", , drop = FALSE]
  if (nrow(warn)) {
    cli::cli_warn(c("{.file {what}} has {nrow(warn)} warning{?s}; see {.fn validate_rulebook}.",
                    stats::setNames(esc(utils::head(paste0(warn$path, ": ", warn$message), 5)),
                                    rep("!", min(5, nrow(warn))))),
                  call = call)
  }
  invisible(v)
}
