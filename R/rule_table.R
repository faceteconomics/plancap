#' Every rule in a rulebook as one table
#'
#' Flattens a rulebook into a long table with one row per rule: what it
#' applies to, what it says, the conditions on it, and its citation. Useful as
#' an appendix to a report, and for checking a rulebook against the plan.
#'
#' @param rb A `plancap_rulebook`.
#' @return A data frame with columns `scope` (`"zone"`, `"overlay"`,
#'   `"area"`, `"bonus"`, `"entitlement"` or `"unmodelled"`), `id`, `zone`,
#'   `rule`, `value`, `applies_to`, `conditions`, `variant` and `source`.
#' @export
#' @examples
#' rb <- rulebook("Exampleton") |>
#'   add_zone(zone("LDR", height = height_limit(8, source = "LDR-S1"),
#'                 setbacks = list(yard(3, "road", source = "LDR-S2")),
#'                 coverage = ratio(0.35, source = "LDR-S3")))
#' rule_table(rb)
rule_table <- function(rb) {
  check_rulebook(rb)
  rows <- list()
  push <- function(...) rows[[length(rows) + 1]] <<- row_df(...)

  for (k in names(rb$zones)) zone_rows(rb$zones[[k]], "zone", k, k, push)
  for (o in names(rb$overlays)) {
    ov <- rb$overlays[[o]]
    val <- ov[["value"]] %||% (if (!is.null(ov[["value_field"]])) paste0("<", ov[["value_field"]], ">"))
    push("overlay", o, NA, paste(ov$type, ov$combine %||% ""),
         fmt_value(val), paste0("layer ", ov$layer),
         paste(ov$applies_to_zones, collapse = ", "), NA, ov$source)
    if (!is.null(ov$parameters)) zone_rows(ov$parameters, "overlay", o, NA, push)
    if (!is.null(ov$additions)) zone_rows(ov$additions, "overlay", paste0(o, " (added)"), NA, push)
  }
  for (a in names(rb$areas)) {
    ar <- rb$areas[[a]]
    push("area", a, NA, paste("area", ar$combine %||% "replace"), NA,
         paste0("layer ", ar$layer), paste(ar$applies_to_zones, collapse = ", "), NA, ar$source)
    if (!is.null(ar$parameters)) zone_rows(ar$parameters, "area", a, NA, push)
    if (!is.null(ar$additions)) zone_rows(ar$additions, "area", paste0(a, " (added)"), NA, push)
    for (zk in names(ar$zone_parameters)) zone_rows(ar$zone_parameters[[zk]], "area", a, zk, push)
    for (sk in names(ar$sub_areas)) {
      zone_rows(ar$sub_areas[[sk]], "area", paste0(a, "/", sk), NA, push)
    }
    for (t in names(ar$totals)) push("area", a, NA, paste0("totals.", t), fmt_value(ar$totals[[t]]),
                                     NA, NA, NA, ar$source)
  }
  for (b in names(rb$bonuses)) {
    x <- rb$bonuses[[b]]
    push("bonus", b, paste(x$applies_to_zones, collapse = ", "),
         paste(x$quantity, x$combine), fmt_value(x$value), x$condition,
         describe_conditions(x$when), NA, x$source)
  }
  for (e in names(rb$entitlements)) {
    x <- rb$entitlements[[e]]
    push("entitlement", e, paste(x$applies_to_zones, collapse = ", "),
         paste(x$quantity, "floor"), fmt_value(x$value), NA,
         describe_conditions(x$when), NA, x$source)
  }
  for (u in rb$unmodelled_rules) {
    push("unmodelled", NA, paste(u$zones, collapse = ", "), u$rule,
         u$likely_effect %||% "unknown", u$reason, NA, NA, u$source)
  }
  if (!length(rows)) return(row_df()[0, ])
  do.call(rbind, rows)
}

row_df <- function(scope = NA, id = NA, zone = NA, rule = NA, value = NA, applies_to = NA,
                   conditions = NA, variant = NA, source = NA) {
  na <- function(x) if (is.null(x) || !length(x) || identical(x, "")) NA_character_ else as.character(x)[1]
  data.frame(scope = na(scope), id = na(id), zone = na(zone), rule = na(rule),
             value = na(value), applies_to = na(applies_to), conditions = na(conditions),
             variant = na(variant), source = na(source), stringsAsFactors = FALSE)
}

fmt_value <- function(v) {
  if (is.null(v)) return(NA_character_)
  if (is.numeric(v)) return(paste(format(v, trim = TRUE, digits = 6), collapse = ", "))
  if (is.logical(v)) return(as.character(v))
  if (is.character(v)) return(paste(v, collapse = ", "))
  if (!is.null(v$bands)) return(fmt_bands(v$bands))
  if (!is.null(v$value)) return(fmt_value(v$value))
  NA_character_
}

fmt_bands <- function(b) {
  parts <- vapply(b$bands, function(x) {
    paste0(if (is.null(x$max)) paste0(">", format(x$min %||% 0)) else paste0("<=", format(x$max)),
           ": ", fmt_value(x$value))
  }, "")
  paste0("by ", b$by, " [", paste(parts, collapse = "; "), "]")
}

describe_setback <- function(s) {
  switch(s$kind,
    yard = paste0(fmt_value(s$distance), " m"),
    upper_level = paste0(fmt_value(s$distance), " m",
                         if (!is.null(s$above_height)) paste0(" above ", s$above_height, " m"),
                         if (!is.null(s$from_storey)) paste0(" from storey ", s$from_storey)),
    plane = paste0(if (!is.null(s$angle_by_bearing)) "angle by bearing" else paste0(round(s$angle_deg, 2), " deg"),
                   " from ", fmt_value(s$start_height), " m",
                   if (!is.null(s$set_in)) paste0(", set in ", s$set_in, " m")),
    proportional = paste0(s$ratio, " x H", if (!is.null(s$min)) paste0(", min ", s$min),
                          if (!is.null(s$max)) paste0(", max ", s$max)),
    profile = paste0("profile of ", length(s$points), " points"),
    NA_character_
  )
}

describe_conditions <- function(w) {
  if (is.null(w) || !length(w)) return(NA_character_)
  parts <- vapply(names(w), function(n) paste0(n, " ", paste(format(w[[n]]), collapse = ",")), "")
  paste(parts, collapse = "; ")
}

zone_rows <- function(z, scope, id, zone_key, push) {
  if (!is.null(z$method)) push(scope, id, zone_key, "method", z$method, NA, NA, NA, z$source)
  h <- z$height
  if (!is.null(h)) {
    val <- if (!is.null(h$from_overlay)) paste0("<", h$from_overlay, ">")
           else if (isTRUE(h$no_limit)) "no limit" else fmt_value(h$value)
    extra <- c(if (!is.null(h$occupiable)) paste0("occupiable ", h$occupiable),
               if (!is.null(h$storeys)) paste0(h$storeys, " storeys"))
    push(scope, id, zone_key, "height", paste(c(val, extra), collapse = "; "), NA, NA, NA,
         h$source %||% z$source)
  }
  for (s in z$setbacks) {
    push(scope, id, zone_key, paste0("setback:", s$kind), describe_setback(s),
         paste(s$boundaries, collapse = ", "), describe_conditions(s$when), s$variant,
         s$source %||% z$source)
  }
  for (r in names(z$ratios)) {
    v <- z$ratios[[r]]
    push(scope, id, zone_key, r, fmt_value(v), NA, NA, NA,
         (if (is.list(v)) v$source %||% v$bands$source) %||% z$source)
  }
  for (part in c("form", "density", "use")) {
    p <- z[[part]]
    for (f in setdiff(names(p), "source")) {
      push(scope, id, zone_key, paste0(part, ".", f),
           if (f == "access_width") paste(length(p[[f]]), "bands") else if (f == "site_shape")
             paste(p[[f]]$width, "x", p[[f]]$depth) else if (f == "large_site")
               paste(names(p[[f]]), unlist(p[[f]]), collapse = "; ") else fmt_value(p[[f]]),
           NA, NA, NA, p$source %||% z$source)
    }
  }
}
