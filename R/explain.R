#' Explain one site's capacity
#'
#' Everything behind one site's figures: what it is (zone, area, frontage,
#' corner or rear), which rules apply (the zone, and the precincts and
#' overlays that change it), every boundary with the setback applied at each
#' storey and the rule and citation that set it, the storey stack with what
#' bound each storey, and how floor area became dwellings.
#'
#' The site's envelope is rebuilt with its setbacks kept, on the same inputs
#' and options as the capacity run.
#'
#' @param cap A capacity result from [estimate_capacity()].
#' @param site_id The site to explain.
#' @return A `plancap_explanation` list: `site` (one row), `rules` (the
#'   zone, areas and overlays that apply, with the key values),
#'   `boundaries` (one row per boundary segment), `setbacks` (one row per
#'   boundary and storey), `storeys` (one row per storey) and `dwellings`.
#'   Printing it gives a readable account.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' cap <- estimate_capacity(sc)
#' explain_site(cap, cap$sites$site_id[which.max(cap$sites$floor_area)])
explain_site <- function(cap, site_id) {
  check_capacity_object(cap)
  check_string(site_id, null_ok = FALSE)
  x <- cap$inputs
  if (is.null(x)) cli::cli_abort("This capacity result does not carry its scenario; rerun {.fn estimate_capacity}.")
  s <- sf::st_drop_geometry(cap$sites)
  if (!site_id %in% s$site_id) cli::cli_abort("No site {.val {site_id}} in this result.")
  row <- s[s$site_id == site_id, , drop = FALSE]
  prep <- prepare_sites(x)
  rb <- x$rulebook
  opts <- cap$options[intersect(names(cap$options), c("variant_choice", "max_storeys"))]
  env <- do.call(build_envelopes, c(list(x, include_density = TRUE, keep_setbacks = TRUE, .only = site_id), opts))
  seg <- sf::st_drop_geometry(prep$segments)
  seg <- seg[seg$site_id == site_id, , drop = FALSE]
  keep <- intersect(c("segment_id", "boundary_class", "tags", "length", "outward_bearing", "adjacent_zone_key",
                      "adjacent_zone_code", "road_shared_length", "water_distance", "ground",
                      "existing_front_setback"), names(seg))
  boundaries <- seg[, keep, drop = FALSE]
  rownames(boundaries) <- NULL
  sb <- env$setbacks %||% data.frame()
  if (nrow(sb)) {
    sb <- sb[sb$site_id == site_id, setdiff(names(sb), "site_id"), drop = FALSE]
    sb$boundary_class <- seg$boundary_class[match(sb$segment_id, seg$segment_id)]
    sb <- sb[order(sb$storey, match(sb$segment_id, seg$segment_id)), c("segment_id", "boundary_class", "storey",
                                                                      "level", "setback", "rule", "source")]
    rownames(sb) <- NULL
  }
  st <- cap$stack[cap$stack$site_id == site_id, , drop = FALSE]
  est <- cap$envelope$stack[cap$envelope$stack$site_id == site_id, , drop = FALSE]
  storeys <- data.frame(storey = est$storey, floor_level = est$floor_level, ceiling_level = est$ceiling_level,
                        buildable_area = est$clipped_area, envelope_area = est$enabled_area,
                        envelope_binding = est$binding)
  storeys$enabled_area <- st$enabled_area[match(storeys$storey, st$storey)] %|NA|% 0
  storeys$binding <- st$binding[match(storeys$storey, st$storey)] %|NA|% "far"
  storeys$residential_area <- st$residential_area[match(storeys$storey, st$storey)] %|NA|% 0
  # Rules: the zone, the areas and overlays that reach this site.
  rules <- site_rules(site_id, row, prep, rb)
  dwell <- list(path = row$path, method = row$method, dwellings = row$dwellings,
                minor_dwellings = row$minor_dwellings, binding = row$dwelling_binding,
                access_width = row$access_width, access_method = row$access_method,
                site_shape_fits = row$site_shape_fits, conversion = conversion_note(cap$conversion))
  structure(list(site = row, rules = rules, boundaries = boundaries, setbacks = sb, storeys = storeys,
                 dwellings = dwell, scenario = cap$scenario, report = env$report),
            class = "plancap_explanation")
}

`%|NA|%` <- function(x, y) ifelse(is.na(x), y, x)

site_rules <- function(site_id, row, prep, rb) {
  out <- list()
  z <- rb$zones[[row$zone_key]]
  out[[1]] <- data.frame(kind = "zone", name = row$zone_key %||% NA_character_,
                         detail = if (is.null(z)) "no rules" else if (identical(z$name, row$zone_key)) "" else z$name %||% "",
                         source = if (is.null(z)) NA_character_ else z$source %||% NA_character_,
                         stringsAsFactors = FALSE)
  ar <- prep$areas[prep$areas$site_id == site_id & prep$areas$share >= 0.5, , drop = FALSE]
  if (nrow(ar)) {
    out[[2]] <- data.frame(kind = "area", name = ar$area,
                           detail = ifelse(is.na(ar$sub_area), "", paste("sub-area", ar$sub_area)),
                           source = vapply(ar$area, function(a) rb$areas[[a]]$source %||% NA_character_, ""),
                           stringsAsFactors = FALSE)
  }
  ov <- prep$overlays[prep$overlays$site_id == site_id, , drop = FALSE]
  if (nrow(ov)) {
    out[[3]] <- data.frame(kind = "overlay", name = ov$overlay,
                           detail = paste0(vapply(ov$overlay, function(o) rb$overlays[[o]]$type %||% "", ""),
                                           ifelse(is.na(ov$value), "", paste0(" = ", ov$value)),
                                           sprintf(" (%.0f%% of site)", 100 * ov$share)),
                           source = vapply(ov$overlay, function(o) rb$overlays[[o]]$source %||% NA_character_, ""),
                           stringsAsFactors = FALSE)
  }
  r <- do.call(rbind, out)
  rownames(r) <- NULL
  r
}

#' @export
print.plancap_explanation <- function(x, ...) {
  s <- x$site
  f <- function(v) format(round(v, 1), big.mark = ",")
  cli::cli_h2("Site {s$site_id} ({x$scenario})")
  cli::cli_text("{s$zone_key %||% 'no zone'}; {f(s$area)} m2{if (!is.na(s$net_area) && abs(s$net_area - s$area) > 0.5) paste0(' (', f(s$net_area), ' m2 net)')}; \\
                 floor area {f(s$floor_area)} m2 in {s$storeys} storey{?s} \\
                 (height allows {s$storeys_allowed %||% NA}); {s$dwellings} dwelling{?s} by the {s$path %||% 'no'} path.")
  cli::cli_h3("Rules")
  for (i in seq_len(nrow(x$rules))) {
    r <- x$rules[i, ]
    cli::cli_text("{r$kind}: {.strong {r$name}} {r$detail}{if (!is.na(r$source)) paste0(' [', r$source, ']')}")
  }
  cli::cli_h3("Boundaries")
  b <- x$boundaries
  print(data.frame(segment = b$segment_id, class = b$boundary_class, length = round(b$length, 1),
                   across = b$adjacent_zone_key %||% NA), row.names = FALSE)
  if (nrow(x$setbacks)) {
    cli::cli_h3("Setbacks at the ground storey")
    g <- x$setbacks[x$setbacks$storey == 1, ]
    print(data.frame(segment = g$segment_id, class = g$boundary_class, setback = round(g$setback, 2),
                     rule = g$rule, source = g$source), row.names = FALSE)
  }
  cli::cli_h3("Storeys")
  st <- x$storeys
  print(data.frame(storey = st$storey, ceiling = round(st$ceiling_level, 2), buildable = round(st$buildable_area, 1),
                   enabled = round(st$enabled_area, 1), limited_by = st$binding), row.names = FALSE)
  d <- x$dwellings
  cli::cli_h3("Dwellings")
  cli::cli_text("{d$dwellings} by the {d$path %||% 'no'} path, limited by {d$binding %||% 'nothing'}\\
                 {if (!is.na(d$access_width %||% NA)) paste0('; access ', round(d$access_width, 2), ' m (', d$access_method, ')')}. \\
                 {.emph {d$conversion}}")
  invisible(x)
}

#' Floor area lost to each kind of rule
#'
#' A waterfall from a theoretical maximum (every site built over its whole
#' area to as many storeys as its height allows) down to the enabled floor
#' area, in the order the engine applies the rules:
#'
#' 1. `storeys_not_reached`: storeys the height allows that the stack never
#'    reaches, because setbacks, planes or caps left too small a floor;
#' 2. `setbacks_and_land`: land each built storey loses to yards, planes,
#'    access legs, water yards, exclusions, height surfaces and building
#'    gaps;
#' 3. one step per cap that bound a storey (`coverage`, `landscaping`,
#'    `impervious`, `floorplate`, `tower_floorplate`, and
#'    `stack_monotonic`, a storey kept no larger than the one below);
#' 4. `far` and `max_site_floorspace`: limits on the site's total.
#'
#' The steps add up exactly: the theoretical maximum less every loss is the
#' enabled floor area.
#'
#' @param cap A capacity result from [estimate_capacity()].
#' @param by Optional grouping, as for [summarise_capacity()] (site
#'   columns or `"zone"`).
#' @return A data frame of class `plancap_breakdown`: the grouping columns,
#'   `step`, `floor_area` (the loss, or for the first and last steps the
#'   amount) and `remaining` after the step.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' constraint_breakdown(estimate_capacity(sc))
constraint_breakdown <- function(cap, by = NULL) {
  check_capacity_object(cap)
  s <- sf::st_drop_geometry(cap$sites)
  keys <- by_columns(by)
  miss <- setdiff(keys, names(s))
  if (length(miss)) cli::cli_abort("Cannot group by {.val {miss}}.")
  grp <- if (length(keys)) interaction(s[keys], drop = TRUE, lex.order = TRUE) else factor(rep("all", nrow(s)))
  allowed <- s$storeys_allowed %|NA|% 0
  est <- cap$envelope$stack
  cst <- cap$stack
  gi <- grp[match(est$site_id, s$site_id)]
  cap_order <- c("coverage", "landscaping", "impervious", "floorplate", "tower_floorplate", "stack_monotonic")
  rows <- lapply(levels(grp), function(g) {
    k <- which(grp == g)
    e <- est[gi %in% g, , drop = FALSE]
    c2 <- cst[cst$site_id %in% s$site_id[k], , drop = FALSE]
    theoretical <- sum(s$area[k] * allowed[k])
    built_land <- sum(s$area[match(e$site_id, s$site_id)])
    not_reached <- theoretical - built_land
    setbacks <- built_land - sum(e$clipped_area)
    cap_loss <- vapply(cap_order, function(b) sum((e$clipped_area - e$enabled_area)[e$binding %in% b]), 0)
    other <- sum(e$clipped_area - e$enabled_area) - sum(cap_loss)
    env_total <- sum(e$enabled_area)
    final <- sum(c2$enabled_area)
    far_rows <- c2$binding %in% c("far", "max_site_floorspace")
    # The total limits, split by which bound (a storey cut to nothing has
    # left the stack, so the split is by site).
    lim <- env_total - final
    site_lim <- tapply(c2$binding, c2$site_id, function(b) if ("max_site_floorspace" %in% b) "max_site_floorspace" else "far")
    e_by <- tapply(e$enabled_area, e$site_id, sum)
    c_by <- tapply(c2$enabled_area, c2$site_id, sum)
    ids <- names(e_by)
    loss_by <- e_by - (c_by[ids] %|NA|% 0)
    lim_kind <- site_lim[ids] %|NA|% "far"
    far_loss <- sum(loss_by[lim_kind == "far"])
    msf_loss <- sum(loss_by[lim_kind == "max_site_floorspace"])
    steps <- c(theoretical = theoretical, storeys_not_reached = not_reached, setbacks_and_land = setbacks,
               cap_loss, other_caps = other, far = far_loss, max_site_floorspace = msf_loss)
    rem <- theoretical - cumsum(c(0, steps[-1]))
    df <- data.frame(step = c(names(steps), "enabled"), floor_area = c(steps, final),
                     remaining = c(rem, final), stringsAsFactors = FALSE)
    df <- df[df$step %in% c("theoretical", "enabled", "storeys_not_reached", "setbacks_and_land") |
               abs(df$floor_area) > 1e-6, , drop = FALSE]
    if (length(keys)) df <- cbind(s[k[1], keys, drop = FALSE][rep(1, nrow(df)), , drop = FALSE], df)
    df
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "by") <- keys
  attr(out, "scenario") <- cap$scenario
  class(out) <- c("plancap_breakdown", "data.frame")
  out
}

#' @export
print.plancap_breakdown <- function(x, ...) {
  cli::cli_text("{.strong <plancap constraint breakdown>} {attr(x, 'scenario')}")
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  df$floor_area <- formatC(round(df$floor_area), format = "d", big.mark = ",")
  df$remaining <- formatC(round(df$remaining), format = "d", big.mark = ",")
  print(df, row.names = FALSE, right = TRUE)
  invisible(x)
}

#' Reconciliation and diagnostics for a capacity result
#'
#' Checks that nothing was lost or double counted and lists anything that
#' looks wrong: every parcel accounted for, land in equal to land out, floor
#' area by storey adding to floor area by site, no missing or negative
#' values, no site above what its height allows, and a tally of sites with
#' no capacity by reason.
#'
#' @param cap A capacity result from [estimate_capacity()].
#' @return A data frame of class `plancap_checks`: `check`, `status`
#'   (`"ok"`, `"warn"` or `"fail"`), `value` and `detail`.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' check_capacity(estimate_capacity(sc))
check_capacity <- function(cap) {
  check_capacity_object(cap)
  s <- sf::st_drop_geometry(cap$sites)
  x <- cap$inputs
  out <- list()
  add <- function(check, ok, value, detail, warn_only = FALSE) {
    out[[length(out) + 1]] <<- data.frame(check = check,
                                          status = if (ok) "ok" else if (warn_only) "warn" else "fail",
                                          value = as.character(value), detail = detail, stringsAsFactors = FALSE)
  }
  if (!is.null(x)) {
    pids <- unique(unlist(prepare_sites(x)$sites$parcel_ids))
    n_in <- nrow(x$parcels)
    add("parcels accounted for", length(pids) == n_in, sprintf("%d of %d", length(pids), n_in),
        "every input parcel is in a site")
    land_in <- sum(geos::geos_area(geos::geos_make_valid(as_geos(x$parcels))))
    land_out <- sum(s$area)
    add("land in equals land out", abs(land_out - land_in) <= 1e-6 * max(land_in, 1) + 1,
        sprintf("%.0f of %.0f m2", land_out, land_in), "site areas add to parcel areas (overlaps aside)")
  }
  st_tot <- sum(cap$stack$enabled_area)
  add("storeys add to sites", abs(st_tot - sum(s$floor_area)) < 1e-6 * max(st_tot, 1) + 0.01,
      sprintf("%.0f m2", st_tot), "floor area by storey equals floor area by site")
  add("uses add to floor area", abs(sum(s$residential_floor_area + s$business_floor_area) - sum(s$floor_area)) <
        1e-6 * max(sum(s$floor_area), 1) + 0.01, "", "residential plus business equals floor area")
  bad <- sum(is.na(s$floor_area) | is.na(s$dwellings) | s$floor_area < 0 | s$dwellings < 0)
  add("no missing or negative values", bad == 0, bad, "floor area and dwellings")
  allowed <- s$storeys_allowed %|NA|% Inf
  over <- sum(s$floor_area > s$area * allowed + 0.01)
  add("within the height's storeys", over == 0, over, "no site above its area times its storeys")
  dup <- anyDuplicated(s$site_id)
  add("site ids unique", dup == 0, dup, "")
  orphan <- sum(s$path %in% "volumetric" & s$floor_area == 0 & s$dwellings > 0)
  add("dwellings need floor area", orphan == 0, orphan, "volumetric sites with dwellings but no floor area",
      warn_only = TRUE)
  noacc <- sum(s$access_unmeasured %in% TRUE)
  add("access measured", noacc == 0, noacc, "sites the access width table could not be applied to",
      warn_only = TRUE)
  fl <- table(s$flag)
  add("flags", TRUE, paste(names(fl), fl, sep = " ", collapse = ", "), "sites by flag")
  zero <- s[s$floor_area == 0 & s$dwellings == 0, , drop = FALSE]
  if (nrow(zero)) {
    why <- ifelse(zero$flag != "ok", zero$flag, zero$envelope_binding %|NA|% "no_envelope")
    zt <- sort(table(why), decreasing = TRUE)
    add("sites with no capacity", TRUE, nrow(zero), paste(names(zt), zt, collapse = ", "))
  }
  rep <- cap$report$envelope
  for (nm in c("front_yard_unmeasured", "surfaces_missing", "no_height", "tower_controls_unmodelled")) {
    v <- rep[[nm]]
    if (!is.null(v) && length(v) && !identical(v, 0L) && !identical(v, 0) && !identical(v, character())) {
      add(gsub("_", " ", nm), FALSE, paste(v, collapse = ", "), "from the envelope report", warn_only = TRUE)
    }
  }
  r <- do.call(rbind, out)
  class(r) <- c("plancap_checks", "data.frame")
  r
}

#' @export
print.plancap_checks <- function(x, ...) {
  for (i in seq_len(nrow(x))) {
    msg <- paste0(x$check[i], ": ", x$value[i], if (nzchar(x$detail[i])) paste0(" (", x$detail[i], ")"))
    switch(x$status[i], ok = cli::cli_alert_success(msg), warn = cli::cli_alert_warning(msg),
           cli::cli_alert_danger(msg))
  }
  invisible(x)
}

#' The register of rules not modelled
#'
#' Every rulebook lists the rules it does not model, with the reason and the
#' likely direction of the effect on capacity. This returns that register as
#' a table, for a report's assumptions section.
#'
#' @param x A rulebook, or a capacity result (its rulebook).
#' @return A data frame: `rule`, `reason`, `zones`, `likely_effect`, `size`
#'   and `source`.
#' @export
#' @examples
#' unmodelled_report(rulebook_example("exampleton"))
unmodelled_report <- function(x) {
  rb <- if (inherits(x, "plancap_capacity")) x$rulebook else x
  check_rulebook(rb)
  u <- rb$unmodelled_rules %||% list()
  if (!length(u)) {
    return(data.frame(rule = character(), reason = character(), zones = character(),
                      likely_effect = character(), size = character(), source = character()))
  }
  data.frame(rule = vapply(u, function(r) r$rule %||% NA_character_, ""),
             reason = vapply(u, function(r) r$reason %||% NA_character_, ""),
             zones = vapply(u, function(r) paste(unlist(r$zones), collapse = ", "), ""),
             likely_effect = vapply(u, function(r) r$likely_effect %||% "unknown", ""),
             size = vapply(u, function(r) as.character(r$size %||% NA_character_), ""),
             source = vapply(u, function(r) r$source %||% NA_character_, ""),
             stringsAsFactors = FALSE)
}
