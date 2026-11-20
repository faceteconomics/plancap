#' Check a rulebook
#'
#' Checks a rulebook in three passes:
#'
#' 1. **Structure**, against the JSON Schema ([rulebook_schema_path()]): every
#'    key known, every value the right type. A misspelt key is an error, not
#'    silently ignored.
#' 2. **Consistency**: every zone, family, overlay and layer a rule refers to
#'    exists; bands ascend; formulas use only known variables; each zone has
#'    what its method needs.
#' 3. **Lint** (warnings): values without a citation, zones no code maps to,
#'    rules that nothing will read.
#'
#' @param rb A `plancap_rulebook`.
#' @return A `plancap_validation`: a list with `valid` (no errors) and
#'   `issues`, a data frame of `severity`, `path` and `message`.
#' @export
#' @examples
#' rb <- rulebook("Exampleton") |>
#'   add_zone(zone("LDR", height = height_limit(8)))
#' validate_rulebook(rb)
validate_rulebook <- function(rb) {
  check_rulebook(rb)
  issues <- list()
  add <- function(severity, path, message) {
    issues[[length(issues) + 1]] <<- data.frame(severity = severity, path = path,
                                                message = message, stringsAsFactors = FALSE)
  }

  # 1. Structure
  json <- rulebook_to_json(rb)
  ok <- schema_validator()(json, verbose = TRUE, greedy = TRUE)
  if (!ok) {
    errs <- attr(ok, "errors")
    for (i in seq_len(nrow(errs))) {
      path <- errs$instancePath[i] %||% errs$dataPath[i] %||% ""
      msg <- errs$message[i]
      if (!is.null(errs$params) && !is.null(errs$params$additionalProperty) &&
          !is.na(errs$params$additionalProperty[i])) {
        msg <- paste0(msg, ": '", errs$params$additionalProperty[i], "'")
      }
      if (!is.null(errs$params) && !is.null(errs$params$allowedValues) &&
          length(errs$params$allowedValues[[i]])) {
        msg <- paste0(msg, " (", paste(errs$params$allowedValues[[i]], collapse = ", "), ")")
      }
      add("error", if (nzchar(path)) path else "/", msg)
    }
  }

  # 2 and 3. Consistency and lint
  zones <- names(rb$zones)
  fams <- names(rb$zone_families)
  ovs <- names(rb$overlays)
  zone_or_family <- c(zones, fams, "any")
  classes <- boundary_classes()

  for (code in names(rb$zone_map)) {
    if (!rb$zone_map[[code]] %in% zones) {
      add("error", paste0("/zone_map/", code), paste0("maps to unknown zone '", rb$zone_map[[code]], "'"))
    }
  }
  for (f in fams) {
    bad <- setdiff(family_zones(rb$zone_families[[f]]), zones)
    if (length(bad)) {
      add("error", paste0("/zone_families/", f), paste0("unknown zone(s): ", paste(bad, collapse = ", ")))
    }
  }
  unmapped <- setdiff(zones, unlist(rb$zone_map))
  for (z in unmapped) add("warning", paste0("/zones/", z), "no zone code maps to this zone")

  check_zone_body <- function(z, path, full) {
    if (full) {
      m <- z$method %||% ""
      if (m %in% c("volumetric", "hybrid") && is.null(z$height)) {
        add("error", path, "a volumetric zone needs a height")
      }
      if (m %in% c("density", "hybrid") && is.null(z$density)) {
        add("error", path, "a density zone needs density rules")
      }
      if (m != "none" && is.null(z$source)) {
        has_cited <- !is.null(z$height$source) || any(vapply(z$setbacks %||% list(),
                                                           function(s) !is.null(s$source), logical(1)))
        if (!has_cited) add("warning", path, "no citation anywhere in this zone")
      }
    }
    h <- z$height
    if (!is.null(h)) {
      if (!is.null(h$from_overlay) && !h$from_overlay %in% ovs) {
        add("error", paste0(path, "/height"), paste0("from_overlay names unknown overlay '", h$from_overlay, "'"))
      }
      if (is.numeric(h$value) && is.numeric(h$occupiable) && h$occupiable > h$value) {
        add("error", paste0(path, "/height"), "occupiable height exceeds total height")
      }
      if (is.null(h$source) && is.null(z$source)) add("warning", paste0(path, "/height"), "height has no source")
      check_formula_field(h$value, paste0(path, "/height/value"), add)
    }
    declared_variants <- names(z$variants)
    for (i in seq_along(z$setbacks)) {
      s <- z$setbacks[[i]]
      sp <- paste0(path, "/setbacks/", i - 1)
      bad <- setdiff(s$boundaries, classes)
      if (length(bad)) add("warning", sp, paste0("boundary class not built in: ", paste(bad, collapse = ", "),
                                                 " (needs its own layer)"))
      for (k in c("adjacent_zones", "not_adjacent_zones")) {
        badz <- setdiff(s$when[[k]], zone_or_family)
        if (length(badz)) add("error", paste0(sp, "/when/", k),
                              paste0("unknown zone or family: ", paste(badz, collapse = ", ")))
      }
      if (!is.null(s$variant) && length(declared_variants) && !s$variant %in% declared_variants) {
        add("warning", sp, paste0("variant '", s$variant, "' is not declared in the zone's variants"))
      }
      if (is.null(s$source) && is.null(z$source)) add("warning", sp, "setback has no source")
      check_formula_field(s$distance, paste0(sp, "/distance"), add)
      check_formula_field(s$start_height, paste0(sp, "/start_height"), add)
      if (identical(s$kind, "profile") && length(s$points) > 1) {
        hs <- vapply(s$points, `[[`, numeric(1), 1)
        if (is.unsorted(hs, strictly = TRUE)) add("error", paste0(sp, "/points"), "heights must ascend")
      }
    }
    for (r in names(z$ratios)) {
      v <- z$ratios[[r]]
      rp <- paste0(path, "/ratios/", r)
      if (is.list(v)) {
        if (!is.null(v$bands)) check_bands(v$bands, rp, add)
        check_formula_field(v$value, paste0(rp, "/value"), add)
        if (is.numeric(v$value) && r != "far_max" && (v$value < 0 || v$value > 1)) {
          add("error", rp, "a share of site area must be between 0 and 1")
        }
        if (is.null(v$source) && is.null(z$source)) add("warning", rp, "ratio has no source")
      }
    }
    rs <- z$use$residential_share
    if (is.list(rs) && !is.null(rs$bands)) {
      check_bands(rs$bands, paste0(path, "/use/residential_share"), add)
    }
  }

  for (k in zones) check_zone_body(rb$zones[[k]], paste0("/zones/", k), full = TRUE)

  check_zone_refs <- function(x, path) {
    bad <- setdiff(x, zones)
    if (length(bad)) add("error", path, paste0("unknown zone(s): ", paste(bad, collapse = ", ")))
  }
  for (o in ovs) {
    ov <- rb$overlays[[o]]
    p <- paste0("/overlays/", o)
    check_zone_refs(ov$applies_to_zones, paste0(p, "/applies_to_zones"))
    if (!is.null(ov$parameters)) check_zone_body(ov$parameters, paste0(p, "/parameters"), FALSE)
    if (!is.null(ov$additions)) check_zone_body(ov$additions, paste0(p, "/additions"), FALSE)
    if (is.null(ov$source)) add("warning", p, "overlay has no source")
  }
  for (a in names(rb$areas)) {
    ar <- rb$areas[[a]]
    p <- paste0("/areas/", a)
    check_zone_refs(ar$applies_to_zones, paste0(p, "/applies_to_zones"))
    check_zone_refs(names(ar$zone_parameters), paste0(p, "/zone_parameters"))
    if (!is.null(ar$parameters)) check_zone_body(ar$parameters, paste0(p, "/parameters"), FALSE)
    if (!is.null(ar$additions)) check_zone_body(ar$additions, paste0(p, "/additions"), FALSE)
    for (zk in names(ar$zone_parameters)) {
      check_zone_body(ar$zone_parameters[[zk]], paste0(p, "/zone_parameters/", zk), FALSE)
    }
    for (sk in names(ar$sub_areas)) {
      sa <- ar$sub_areas[[sk]]
      sp <- paste0(p, "/sub_areas/", sk)
      check_zone_body(sa, sp, FALSE)
      if (!is.null(sa$additions)) check_zone_body(sa$additions, paste0(sp, "/additions"), FALSE)
      check_zone_refs(names(sa$zone_parameters), paste0(sp, "/zone_parameters"))
      for (zk in names(sa$zone_parameters)) {
        check_zone_body(sa$zone_parameters[[zk]], paste0(sp, "/zone_parameters/", zk), FALSE)
      }
    }
    if (!is.null(ar$sub_areas) && is.null(ar$sub_area_field)) {
      add("error", p, "sub_areas needs sub_area_field")
    }
    if (is.null(ar$source)) add("warning", p, "area has no source")
  }
  for (b in names(rb$bonuses)) {
    check_zone_refs(rb$bonuses[[b]]$applies_to_zones, paste0("/bonuses/", b, "/applies_to_zones"))
  }
  for (e in names(rb$entitlements)) {
    check_zone_refs(rb$entitlements[[e]]$applies_to_zones, paste0("/entitlements/", e, "/applies_to_zones"))
  }
  for (i in seq_along(rb$unmodelled_rules)) {
    check_zone_refs(rb$unmodelled_rules[[i]]$zones, paste0("/unmodelled_rules/", i - 1, "/zones"))
  }
  rf <- rb$morphology$reserve_families
  if (!is.null(rf) && length(setdiff(rf, fams))) {
    add("warning", "/morphology/reserve_families",
        paste0("family not defined: ", paste(setdiff(rf, fams), collapse = ", ")))
  }
  vc <- rb$variant_choice %||% "max"
  if (!vc %in% c("max", "min")) {
    all_variants <- unique(unlist(lapply(rb$zones, function(z) {
      c(names(z$variants), vapply(z$setbacks %||% list(), function(s) s$variant %||% "", ""))
    })))
    if (!vc %in% all_variants) add("warning", "/variant_choice", paste0("no rule uses variant '", vc, "'"))
  }
  if (is.null(rb$conversion)) {
    add("note", "/conversion", "no floor area to dwellings conversion; dwellings need one at run time")
  }

  df <- if (length(issues)) do.call(rbind, issues) else
    data.frame(severity = character(), path = character(), message = character(),
               stringsAsFactors = FALSE)
  structure(list(valid = !any(df$severity == "error"), issues = df),
            class = "plancap_validation")
}

check_formula_field <- function(v, path, add) {
  if (is_string(v)) {
    res <- tryCatch({ parse_rule_formula(v); NULL }, error = function(e) conditionMessage(e))
    if (!is.null(res)) add("error", path, paste0("bad formula: ", cli::ansi_strip(res)))
  }
}

check_bands <- function(b, path, add) {
  mins <- vapply(b$bands, function(x) x$min %||% 0, numeric(1))
  maxs <- vapply(b$bands, function(x) x$max %||% Inf, numeric(1))
  if (is.unsorted(maxs, strictly = TRUE)) add("error", path, "band upper bounds must ascend")
  if (length(maxs) > 1 && any(abs(mins[-1] - maxs[-length(maxs)]) > 1e-9)) {
    add("error", path, "bands must be contiguous (each band's min equals the previous max)")
  }
  for (i in seq_along(b$bands)) check_formula_field(b$bands[[i]]$value, paste0(path, "/bands/", i - 1), add)
}

#' @export
print.plancap_validation <- function(x, ...) {
  iss <- x$issues
  n <- table(factor(iss$severity, c("error", "warning", "note")))
  if (x$valid) {
    cli::cli_alert_success("Rulebook is valid ({n[['warning']]} warning{?s}, {n[['note']]} note{?s}).")
  } else {
    cli::cli_alert_danger("Rulebook has {n[['error']]} error{?s}, {n[['warning']]} warning{?s}.")
  }
  if (nrow(iss)) {
    sym <- c(error = "x", warning = "!", note = "i")
    shown <- utils::head(iss, 30)
    cli::cli_bullets(stats::setNames(esc(paste0(shown$path, ": ", shown$message)), sym[shown$severity]))
    if (nrow(iss) > 30) cli::cli_text("... and {nrow(iss) - 30} more; see {.code $issues}.")
  }
  invisible(x)
}
