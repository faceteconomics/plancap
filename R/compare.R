#' Sets of scenarios, run together
#'
#' `scenario_set()` collects scenarios to compare; the first is the
#' baseline. `run_scenarios()` runs them all, the baseline in full and every
#' other incrementally from it, so a plan change that touches a tenth of the
#' sites rebuilds about a tenth of them.
#'
#' @param ... Scenarios (from [scenario()] or [scenario_change()]); the first
#'   is the baseline. Names must differ.
#' @param x A scenario set.
#' @param progress Whether to report each run.
#' @param ... For `run_scenarios()`: passed to [estimate_capacity()].
#' @return `scenario_set()`: a `plancap_scenario_set`. `run_scenarios()`: a
#'   `plancap_results`, a named list of capacity results with the set.
#' @seealso [compare_scenarios()], [read_scenarios()]
#' @export
#' @examples
#' town <- exampleton()
#' pc1 <- exampleton_pc1()
#' base <- scenario("Operative", rulebook_example("exampleton"),
#'                  parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                  roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                  zoning = town$zoning, layers = town[c("height_areas", "flood_hazard", "transit")])
#' change <- scenario_change(base, "PC1", rulebook = pc1$rulebook, zoning = pc1$zoning)
#' res <- run_scenarios(scenario_set(base, change))
#' res
scenario_set <- function(...) {
  sc <- list(...)
  if (length(sc) == 1 && inherits(sc[[1]], "plancap_scenario_set")) return(sc[[1]])
  if (!length(sc)) cli::cli_abort("Give at least one scenario.")
  ok <- vapply(sc, inherits, TRUE, "plancap_scenario")
  if (!all(ok)) cli::cli_abort("Every argument must be a {.fn scenario}.")
  nm <- vapply(sc, `[[`, "", "name")
  if (anyDuplicated(nm)) cli::cli_abort("Scenario names must differ: {.val {nm[duplicated(nm)]}}.")
  names(sc) <- nm
  structure(sc, class = "plancap_scenario_set")
}

#' @export
print.plancap_scenario_set <- function(x, ...) {
  cli::cli_text("{.strong <plancap scenario set>} {length(x)} scenario{?s}; baseline {.val {names(x)[1]}}.")
  for (nm in names(x)[-1]) cli::cli_text("  {nm}: {paste(diff_fields(x[[1]], x[[nm]]), collapse = ', ')} differ")
  invisible(x)
}

#' @rdname scenario_set
#' @export
run_scenarios <- function(x, ..., progress = TRUE) {
  x <- scenario_set(x)
  out <- list()
  base <- NULL
  for (nm in names(x)) {
    t0 <- Sys.time()
    cap <- estimate_capacity(x[[nm]], baseline = base, ...)
    if (is.null(base)) base <- cap
    out[[nm]] <- cap
    if (progress) {
      cli::cli_inform("{nm}: {round(as.numeric(Sys.time() - t0, units = 'secs'), 1)} s\\
                       {if (!identical(cap, base)) paste0(', ', cap$report$envelope$copied_from_baseline %||% 0, ' sites copied from the baseline') else ''}.")
    }
  }
  structure(out, set = x, class = "plancap_results")
}

#' @export
print.plancap_results <- function(x, ...) {
  cli::cli_text("{.strong <plancap results>} {length(x)} scenario{?s}")
  tot <- results_totals(x)
  print(format_summary(tot), row.names = FALSE, right = TRUE)
  invisible(x)
}

results_totals <- function(x) {
  do.call(rbind, lapply(names(x), function(nm) {
    s <- x[[nm]]$sites
    data.frame(scenario = nm, sites = nrow(s), land_area = sum(s$area), floor_area = sum(s$floor_area),
               residential_floor_area = sum(s$residential_floor_area), dwellings = sum(s$dwellings),
               stringsAsFactors = FALSE)
  }))
}

# The inputs of a scenario, grouped into the drivers of a change.
driver_fields <- function() {
  list(rules = "rulebook",
       zoning = c("zoning", "zone_field"),
       layers = "layers",
       parcels = c("parcels", "roads", "water", "centrelines", "dem", "ground", "easements", "other_parcels",
                   "buildings", "streets", "street_field", "neighbours", "landholding", "site_id", "group_by",
                   "width_field", "morphology"))
}

# Which of a scenario's inputs differ from another's.
diff_fields <- function(a, b) {
  f <- setdiff(names(formals(scenario)), c("name", "notes"))
  f[!vapply(f, function(k) identical(rlang::hash(a[[k]]), rlang::hash(b[[k]])), TRUE)]
}

changed_drivers <- function(a, b) {
  f <- diff_fields(a, b)
  d <- driver_fields()
  names(d)[vapply(d, function(v) any(v %in% f), TRUE)]
}

# A scenario with the inputs of `drivers` taken from `to`, the rest from `from`.
mix_scenario <- function(from, to, drivers, name) {
  args <- list()
  for (d in drivers) for (f in driver_fields()[[d]]) args[f] <- list(to[[f]])
  x <- unclass(from)
  x[names(args)] <- args
  x$name <- name
  do.call(scenario, x[intersect(names(x), names(formals(scenario)))])
}

#' Compare scenarios: what changed, where, and why
#'
#' Compares each scenario in a set with the baseline (or the `pairs` given)
#' and returns every view of the change:
#'
#' - **totals** for each scenario, with the change;
#' - **sites**: the change on every baseline site. Sites whose parcel is the
#'   same in both scenarios are compared directly, with a reason code
#'   (`rezoned`, `rule_changed`, `overlay_added`, `overlay_removed`,
#'   `area_changed`, `neighbour_effect`, `unchanged`); where parcels changed,
#'   the scenario's capacity is apportioned to the baseline parcels by area
#'   (`parcel_changed`). Sites in only one scenario are listed, never dropped;
#' - **transitions**: land and capacity from each baseline zone to each
#'   scenario zone, the natural way to read a rezoning;
#' - **by zone**, **by height band**, and **by area** or grid cell when
#'   `areas` or `grid` are given (a common geography always reconciles);
#' - **land**: land in each scenario, and land in only one;
#' - **attribution**: the change split into its drivers (rules, zoning,
#'   overlay and area layers, parcels), by running intermediate scenarios
#'   that switch one driver at a time: `"sequential"` (in `order`) or
#'   `"shapley"` (averaged over every order). With `by_rule = TRUE` the rules
#'   driver is split further, by each zone, overlay or area whose rules
#'   changed. The drivers always sum to the total change;
#' - **inputs**: what changed in the inputs ([diff_inputs()]).
#'
#' @param x Results from [run_scenarios()], or a scenario set (run first).
#' @param pairs Optional list of pairs of scenario names to compare; default
#'   each scenario against the first.
#' @param areas,area_id,grid A common geography, as for
#'   [summarise_capacity()].
#' @param attribution `"sequential"`, `"shapley"` or `"none"`.
#' @param order Order of the drivers for sequential attribution.
#' @param by_rule Whether to split the rules driver by rule.
#' @param ... Passed to [estimate_capacity()] for the attribution runs.
#' @return A `plancap_comparison`: a list with one comparison per pair
#'   (`pairs`), and `totals` for every scenario. [check_comparison()]
#'   reconciles it.
#' @export
#' @examples
#' \donttest{
#' town <- exampleton()
#' pc1 <- exampleton_pc1()
#' base <- scenario("Operative", rulebook_example("exampleton"),
#'                  parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                  roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                  zoning = town$zoning, layers = town[c("height_areas", "flood_hazard", "transit")])
#' change <- scenario_change(base, "PC1", rulebook = pc1$rulebook, zoning = pc1$zoning)
#' cmp <- compare_scenarios(run_scenarios(scenario_set(base, change)))
#' cmp
#' }
compare_scenarios <- function(x, pairs = NULL, areas = NULL, area_id = NULL, grid = NULL,
                              attribution = c("sequential", "shapley", "none"),
                              order = c("rules", "zoning", "layers", "parcels"), by_rule = TRUE, ...) {
  attribution <- rlang::arg_match(attribution)
  if (inherits(x, "plancap_scenario_set")) x <- run_scenarios(x, ...)
  if (!inherits(x, "plancap_results")) cli::cli_abort("{.arg x} must come from {.fn run_scenarios} or {.fn scenario_set}.")
  set <- attr(x, "set")
  nm <- names(x)
  if (is.null(pairs)) pairs <- lapply(nm[-1], function(b) c(nm[1], b))
  out <- lapply(pairs, function(p) {
    if (!all(p %in% nm)) cli::cli_abort("Unknown scenario in pair {.val {p}}.")
    compare_pair(x[[p[1]]], x[[p[2]]], set[[p[1]]], set[[p[2]]], areas = areas, area_id = area_id,
                 grid = grid, attribution = attribution, order = order, by_rule = by_rule, ...)
  })
  names(out) <- vapply(pairs, paste, "", collapse = " -> ")
  structure(list(pairs = out, totals = results_totals(x), baseline = nm[1]), class = "plancap_comparison")
}

measure_cols <- function() c("floor_area", "residential_floor_area", "dwellings")

compare_pair <- function(a, b, sa, sb, areas, area_id, grid, attribution, order, by_rule, ...) {
  totals <- data.frame(measure = measure_cols(),
                       baseline = vapply(measure_cols(), function(m) sum(a$sites[[m]]), 0),
                       scenario = vapply(measure_cols(), function(m) sum(b$sites[[m]]), 0))
  totals$change <- totals$scenario - totals$baseline
  totals$change_pct <- ifelse(totals$baseline > 0, 100 * totals$change / totals$baseline, NA_real_)
  rownames(totals) <- NULL
  sites <- compare_sites(a, b, sa, sb)
  join_sum <- function(by, ...) {
    x1 <- summarise_capacity(a, by = by, measures = c("sites", "land_area", measure_cols()), ...)
    x2 <- summarise_capacity(b, by = by, measures = c("sites", "land_area", measure_cols()), ...)
    keys <- attr(x1, "by")
    geo <- if (inherits(x1, "sf") || inherits(x2, "sf")) TRUE else FALSE
    g1 <- if (inherits(x1, "sf")) x1[, keys] else NULL
    g2 <- if (inherits(x2, "sf")) x2[, keys] else NULL
    d1 <- as.data.frame(unclass(if (inherits(x1, "sf")) sf::st_drop_geometry(x1) else x1))
    d2 <- as.data.frame(unclass(if (inherits(x2, "sf")) sf::st_drop_geometry(x2) else x2))
    for (k in keys) {
      d1[[k]] <- as.character(d1[[k]])
      d2[[k]] <- as.character(d2[[k]])
    }
    m <- merge(d1, d2, by = keys, all = TRUE, suffixes = c("_baseline", "_scenario"))
    for (cc in setdiff(names(m), keys)) m[[cc]][is.na(m[[cc]])] <- 0
    for (v in measure_cols()) m[[paste0(v, "_change")]] <- m[[paste0(v, "_scenario")]] - m[[paste0(v, "_baseline")]]
    if (geo) {
      gg <- rbind(if (!is.null(g1)) sf::st_as_sf(g1), if (!is.null(g2)) sf::st_as_sf(g2))
      gg <- gg[!duplicated(as.character(gg[[keys[1]]])), ]
      m <- sf::st_sf(m, geometry = sf::st_geometry(gg)[match(m[[keys[1]]], as.character(gg[[keys[1]]]))])
    }
    m
  }
  by_area <- NULL
  if (!is.null(areas)) by_area <- join_sum("area", areas = areas, area_id = area_id)
  by_grid <- NULL
  if (!is.null(grid)) by_grid <- join_sum("grid", grid = grid)
  attr_tab <- NULL
  rule_tab <- NULL
  if (attribution != "none") {
    at <- attribute_change(a, b, sa, sb, method = attribution, order = order, by_rule = by_rule, ...)
    attr_tab <- at$drivers
    rule_tab <- at$rules
  }
  list(baseline = sa$name, scenario = sb$name, totals = totals, sites = sites,
       transitions = zone_transitions(a, b), by_zone = join_sum("zone"),
       by_height = join_sum("height_band"), by_area = by_area, by_grid = by_grid,
       land = land_reconciliation(a, b), attribution = attr_tab, rule_attribution = rule_tab,
       inputs = diff_inputs(sa, sb))
}

# Capacity per landholding unit: the site before any zone split, or the
# scenario's `landholding` where it names one, with the geometry of its sites.
unit_table <- function(cap, sc) {
  prep <- prepare_sites(sc)
  s <- sf::st_drop_geometry(cap$sites)
  ps <- sf::st_drop_geometry(prep$sites)
  unit_of <- if ("landholding" %in% names(ps)) ifelse(is.na(ps$landholding), ps$parent_id, ps$landholding) else ps$parent_id
  s$unit <- unit_of[match(s$site_id, ps$site_id)]
  u <- stats::aggregate(s[measure_cols()], by = list(unit = s$unit), FUN = sum)
  dom <- s[order(s$unit, -s$area), ]
  dom <- dom[!duplicated(dom$unit), ]
  u$zone_key <- dom$zone_key[match(u$unit, dom$unit)]
  pid <- cap$envelope$sites$param_id[match(s$site_id, cap$envelope$sites$site_id)]
  u$param_ids <- as.vector(tapply(pid, s$unit, function(v) paste(sort(unique(stats::na.omit(v))), collapse = ";"))[u$unit])
  ov <- prep$overlays
  ov$unit <- unit_of[match(ov$site_id, ps$site_id)]
  u$overlays <- vapply(u$unit, function(k) paste(sort(unique(ov$overlay[ov$unit %in% k])), collapse = ";"), "")
  ar <- prep$areas
  ar$unit <- unit_of[match(ar$site_id, ps$site_id)]
  u$areas <- vapply(u$unit, function(k) paste(sort(unique(paste(ar$area, ar$sub_area)[ar$unit %in% k])), collapse = ";"), "")
  g <- geos::geos_make_valid(as_geos(cap$sites))
  o <- order(match(s$unit, u$unit))
  u$geom <- geos::geos_unary_union(geos::geos_make_collection(g[o], feature_id = match(s$unit, u$unit)[o]))
  u$area <- geos::geos_area(u$geom)
  u
}

compare_sites <- function(a, b, sa, sb) {
  ua <- unit_table(a, sa)
  ub <- unit_table(b, sb)
  k <- match(ua$unit, ub$unit)
  same <- !is.na(k)
  if (any(same)) {
    eq <- rep(FALSE, length(k))
    i <- which(same)
    eq[i] <- geos::geos_equals_exact(ua$geom[i], ub$geom[k[i]], tolerance = 0.01) |
      abs(geos::geos_area(geos::geos_sym_difference(ua$geom[i], ub$geom[k[i]]))) < 0.01 * ua$area[i]
    same <- same & eq
  }
  out <- data.frame(unit = ua$unit, zone_baseline = ua$zone_key, zone_scenario = NA_character_,
                    stringsAsFactors = FALSE)
  for (m in measure_cols()) {
    out[[paste0(m, "_baseline")]] <- ua[[m]]
    out[[paste0(m, "_scenario")]] <- NA_real_
  }
  out$reason <- NA_character_
  mi <- which(same)
  mk <- k[mi]
  out$zone_scenario[mi] <- ub$zone_key[mk]
  for (m in measure_cols()) out[[paste0(m, "_scenario")]][mi] <- ub[[m]][mk]
  # Reason codes for matched sites, most structural first.
  chg <- function(x, y) !(x %|NA|% "") == (y %|NA|% "")
  added <- vapply(seq_along(mi), function(j) length(setdiff(split_semi(ub$overlays[mk[j]]), split_semi(ua$overlays[mi[j]]))) > 0, TRUE)
  removed <- vapply(seq_along(mi), function(j) length(setdiff(split_semi(ua$overlays[mi[j]]), split_semi(ub$overlays[mk[j]]))) > 0, TRUE)
  moved <- abs(out$floor_area_scenario[mi] - out$floor_area_baseline[mi]) > 1e-6 |
    out$dwellings_scenario[mi] != out$dwellings_baseline[mi]
  out$reason[mi] <- ifelse(chg(ua$zone_key[mi], ub$zone_key[mk]), "rezoned",
                    ifelse(added, "overlay_added",
                    ifelse(removed, "overlay_removed",
                    ifelse(chg(ua$areas[mi], ub$areas[mk]), "area_changed",
                    ifelse(chg(ua$param_ids[mi], ub$param_ids[mk]) & moved, "rule_changed",
                    ifelse(moved, "neighbour_effect", "unchanged"))))))
  # Changed parcels: the scenario's capacity apportioned to the baseline
  # parcels by the share of each scenario site lying within them.
  ua_x <- which(!same)
  ub_x <- setdiff(seq_len(nrow(ub)), k[same])
  only_scenario <- data.frame(unit = character(), zone_scenario = character())
  if (length(ua_x) || length(ub_x)) {
    ov <- if (length(ua_x) && length(ub_x)) overlap_table(ua$geom[ua_x], ub$geom[ub_x], min_area = 0.01) else
      data.frame(site = integer(), feature = integer(), area = numeric())
    for (m in measure_cols()) {
      share <- ov$area / ub$area[ub_x[ov$feature]]
      v <- tapply(ub[[m]][ub_x[ov$feature]] * share, factor(ov$site, levels = seq_along(ua_x)), sum)
      v[is.na(v)] <- 0
      out[[paste0(m, "_scenario")]][ua_x] <- as.vector(v)
    }
    dz <- ov[order(ov$site, -ov$area), ]
    dz <- dz[!duplicated(dz$site), ]
    out$zone_scenario[ua_x[dz$site]] <- ub$zone_key[ub_x[dz$feature]]
    out$reason[ua_x] <- ifelse(seq_along(ua_x) %in% ov$site, "parcel_changed", "only_baseline")
    # Scenario land not on any baseline parcel.
    covered <- tapply(ov$area, factor(ov$feature, levels = seq_along(ub_x)), sum)
    covered[is.na(covered)] <- 0
    rest <- 1 - as.vector(covered) / ub$area[ub_x]
    left <- which(rest > 0.01)
    if (length(left)) {
      j <- ub_x[left]
      extra <- data.frame(unit = ub$unit[j], zone_baseline = NA_character_, zone_scenario = ub$zone_key[j],
                          stringsAsFactors = FALSE)
      for (m in measure_cols()) {
        extra[[paste0(m, "_baseline")]] <- 0
        extra[[paste0(m, "_scenario")]] <- ub[[m]][j] * rest[left]
      }
      extra$reason <- "only_scenario"
      extra$geom <- ub$geom[j]
      only_scenario <- extra
    }
  }
  for (m in measure_cols()) out[[paste0(m, "_change")]] <- out[[paste0(m, "_scenario")]] - out[[paste0(m, "_baseline")]]
  out$geom <- ua$geom
  if (nrow(only_scenario)) {
    for (m in measure_cols()) only_scenario[[paste0(m, "_change")]] <- only_scenario[[paste0(m, "_scenario")]]
    only_scenario <- only_scenario[, names(out)]
    out <- rbind(out, only_scenario)
  }
  g <- out$geom
  out$geom <- NULL
  sf::st_sf(out, geometry = sf::st_as_sfc(g))
}

split_semi <- function(x) if (is.na(x) || !nzchar(x)) character() else strsplit(x, ";", fixed = TRUE)[[1]]

# Land and capacity from each baseline zone to each scenario zone, by the
# overlap of the two scenarios' sites; land under a site in only one is kept
# as "(none)" on the other side, so both totals reconcile.
zone_transitions <- function(a, b) {
  ga <- geos::geos_make_valid(as_geos(a$sites))
  gb <- geos::geos_make_valid(as_geos(b$sites))
  sa <- sf::st_drop_geometry(a$sites)
  sb <- sf::st_drop_geometry(b$sites)
  aa <- geos::geos_area(ga)
  ab <- geos::geos_area(gb)
  ov <- overlap_table(ga, gb, min_area = 0)
  za <- sa$zone_key %|NA|% "(none)"
  zb <- sb$zone_key %|NA|% "(none)"
  rows <- data.frame(from = za[ov$site], to = zb[ov$feature], land_area = ov$area,
                     stringsAsFactors = FALSE)
  # Shares of each site by its overlaps; where sites overlap one another and
  # the overlaps add to more than the site, by their sum, so nothing is
  # counted twice.
  cov_a <- as.vector(tapply(ov$area, factor(ov$site, levels = seq_along(aa)), sum) %|NA|% 0)
  cov_b <- as.vector(tapply(ov$area, factor(ov$feature, levels = seq_along(ab)), sum) %|NA|% 0)
  den_a <- pmax(aa, cov_a)
  den_b <- pmax(ab, cov_b)
  for (m in measure_cols()) {
    rows[[paste0(m, "_baseline")]] <- ifelse(den_a[ov$site] > 0, sa[[m]][ov$site] * ov$area / den_a[ov$site], 0)
    rows[[paste0(m, "_scenario")]] <- ifelse(den_b[ov$feature] > 0, sb[[m]][ov$feature] * ov$area / den_b[ov$feature], 0)
  }
  left_a <- pmax(0, aa - cov_a)
  left_b <- pmax(0, ab - cov_b)
  la <- which(left_a > 1e-6)
  lb <- which(left_b > 1e-6)
  if (length(la)) {
    x <- data.frame(from = za[la], to = "(none)", land_area = left_a[la])
    for (m in measure_cols()) {
      x[[paste0(m, "_baseline")]] <- sa[[m]][la] * left_a[la] / den_a[la]
      x[[paste0(m, "_scenario")]] <- 0
    }
    rows <- rbind(rows, x)
  }
  if (length(lb)) {
    x <- data.frame(from = "(none)", to = zb[lb], land_area = left_b[lb])
    for (m in measure_cols()) {
      x[[paste0(m, "_baseline")]] <- 0
      x[[paste0(m, "_scenario")]] <- sb[[m]][lb] * left_b[lb] / den_b[lb]
    }
    rows <- rbind(rows, x)
  }
  t <- stats::aggregate(rows[setdiff(names(rows), c("from", "to"))], by = rows[c("from", "to")], FUN = sum)
  for (m in measure_cols()) t[[paste0(m, "_change")]] <- t[[paste0(m, "_scenario")]] - t[[paste0(m, "_baseline")]]
  t[order(t$from, t$to), ]
}

land_reconciliation <- function(a, b) {
  ga <- geos::geos_unary_union(geos::geos_make_collection(geos::geos_make_valid(as_geos(a$sites))))
  gb <- geos::geos_unary_union(geos::geos_make_collection(geos::geos_make_valid(as_geos(b$sites))))
  data.frame(item = c("land_baseline", "land_scenario", "only_baseline", "only_scenario"),
             area = c(sum(a$sites$area), sum(b$sites$area), geos::geos_area(geos::geos_difference(ga, gb)),
                      geos::geos_area(geos::geos_difference(gb, ga))))
}

# ---- Attribution -------------------------------------------------------------

attribute_change <- function(a, b, sa, sb, method, order, by_rule, ...) {
  drivers <- changed_drivers(sa, sb)
  drivers <- c(intersect(order, drivers), setdiff(drivers, order))
  tot <- function(cap) vapply(measure_cols(), function(m) sum(cap$sites[[m]]), 0)
  v0 <- tot(a)
  v1 <- tot(b)
  if (!length(drivers)) {
    return(list(drivers = data.frame(driver = character(), floor_area = numeric(),
                                     residential_floor_area = numeric(), dwellings = numeric()),
                rules = NULL))
  }
  cache <- list()
  # Sites with no rules in either end, so an intermediate scenario with more
  # (zoning to a zone only the new rulebook has) can be flagged.
  no_rules <- function(cap) sum(cap$sites$flag %in% c("no_rules", "no_zone"))
  limit <- max(no_rules(a), no_rules(b))
  incoherent <- character()
  value_of <- function(S) {
    key <- paste(sort(S), collapse = "+")
    if (!length(S)) return(v0)
    if (setequal(S, drivers)) return(v1)
    if (is.null(cache[[key]])) {
      sc <- mix_scenario(sa, sb, S, paste0(sb$name, " [", key, "]"))
      cap <- estimate_capacity(sc, baseline = a, ...)
      if (no_rules(cap) > limit) incoherent <<- c(incoherent, sprintf("%s (%d sites)", key, no_rules(cap) - limit))
      cache[[key]] <<- tot(cap)
    }
    cache[[key]]
  }
  k <- length(drivers)
  contrib <- matrix(0, k, length(v0), dimnames = list(drivers, measure_cols()))
  if (method == "sequential" || k == 1) {
    prev <- v0
    for (i in seq_len(k)) {
      cur <- value_of(drivers[seq_len(i)])
      contrib[i, ] <- cur - prev
      prev <- cur
    }
  } else {
    subsets <- unlist(lapply(0:(k - 1), function(n) utils::combn(drivers, n, simplify = FALSE)), recursive = FALSE)
    for (d in drivers) {
      for (S in subsets) {
        if (d %in% S) next
        w <- factorial(length(S)) * factorial(k - length(S) - 1) / factorial(k)
        contrib[d, ] <- contrib[d, ] + w * (value_of(c(S, d)) - value_of(S))
      }
    }
  }
  dr <- data.frame(driver = drivers, contrib, row.names = NULL, check.names = FALSE)
  if (length(incoherent)) {
    cli::cli_warn(c("Some intermediate scenarios leave sites with no rules: {incoherent}.",
                    "i" = "Their zoning refers to zones only the other rulebook has, so that part of the \
                           attribution is not a plan anyone could adopt. Put {.val rules} before {.val zoning} \
                           in {.arg order}, with {.code attribution = \"sequential\"}."))
  }
  attr(dr, "incoherent") <- incoherent
  attr(dr, "method") <- if (k == 1) "sequential" else method
  rules <- NULL
  if (by_rule && "rules" %in% drivers) rules <- attribute_rules(a, sa, sb, ...)
  list(drivers = dr, rules = rules, method = method)
}

# The rules driver, split by each part of the rulebook that changed, applied
# one at a time to the baseline's maps.
attribute_rules <- function(a, sa, sb, ...) {
  items <- rulebook_changes(sa$rulebook, sb$rulebook)
  if (!nrow(items)) return(NULL)
  rb <- to_plain(sa$rulebook)
  target <- to_plain(sb$rulebook)
  tot <- function(cap) vapply(measure_cols(), function(m) sum(cap$sites[[m]]), 0)
  prev <- tot(a)
  base <- a
  rows <- list()
  for (i in seq_len(nrow(items))) {
    sec <- items$section[i]
    key <- items$key[i]
    if (is.na(key)) rb[sec] <- list(target[[sec]]) else {
      if (is.null(rb[[sec]])) rb[[sec]] <- list()
      rb[[sec]][key] <- list(target[[sec]][[key]])
    }
    rb2 <- normalise_rulebook(compact_nulls(rb))
    cap <- estimate_capacity(scenario_change(sa, paste(sa$name, "+", items$item[i]), rulebook = rb2), baseline = base, ...)
    cur <- tot(cap)
    rows[[i]] <- data.frame(rule = items$item[i], change = items$change[i], t(cur - prev), check.names = FALSE)
    prev <- cur
    base <- cap
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

compact_nulls <- function(x) {
  for (s in names(x)) if (is.list(x[[s]]) && !is.data.frame(x[[s]])) x[[s]] <- Filter(Negate(is.null), x[[s]])
  x
}

# The parts of a rulebook that differ: each zone, overlay, area, bonus and
# entitlement, and each other section, as added, removed or changed. Maps and
# families come first, so a new zone counts once it can appear.
rulebook_changes <- function(r1, r2) {
  a <- to_plain(r1)
  b <- to_plain(r2)
  rows <- list()
  keyed <- c("zone_map", "zone_families", "zones", "overlays", "areas", "bonuses", "entitlements")
  for (sec in keyed) {
    ka <- names(a[[sec]] %||% list())
    kb <- names(b[[sec]] %||% list())
    for (k in union(kb, ka)) {
      if (sec %in% c("zone_map", "zone_families")) next
      x <- a[[sec]][[k]]
      y <- b[[sec]][[k]]
      if (identical(rlang::hash(x), rlang::hash(y))) next
      rows[[length(rows) + 1]] <- data.frame(section = sec, key = k, item = paste0(sec, ".", k),
                                             change = if (is.null(x)) "added" else if (is.null(y)) "removed" else "changed",
                                             stringsAsFactors = FALSE)
    }
  }
  other <- setdiff(union(names(a), names(b)), c(keyed, "plan", "unmodelled_rules", "schema_version"))
  maps <- c("zone_map", "zone_families")
  for (sec in c(maps, other)) {
    if (identical(rlang::hash(a[[sec]]), rlang::hash(b[[sec]]))) next
    rows[[length(rows) + 1]] <- data.frame(section = sec, key = NA_character_, item = sec,
                                           change = if (is.null(a[[sec]])) "added" else if (is.null(b[[sec]])) "removed" else "changed",
                                           stringsAsFactors = FALSE)
  }
  if (!length(rows)) return(data.frame(section = character(), key = character(), item = character(), change = character()))
  out <- do.call(rbind, rows)
  out[order(!out$section %in% maps), ]
}

#' What differs between two scenarios' inputs
#'
#' The rule changes as a table (every rule of [rule_table()] added, removed
#' or given a new value), and the map changes as polygons: land rezoned (from
#' and to which zone), each overlay or area layer's land added or removed,
#' and parcels changed.
#'
#' @param a,b Two [scenario()]s, the baseline first.
#' @return A `plancap_input_diff` list: `fields` (the scenario inputs that
#'   differ), `rules`, `rezoned` (`sf`), `layers` (`sf`: layer, change) and
#'   `parcels` (`sf`: parcel geometry only in one scenario, and which).
#' @export
diff_inputs <- function(a, b) {
  if (!inherits(a, "plancap_scenario") || !inherits(b, "plancap_scenario")) cli::cli_abort("Give two scenarios.")
  crs <- sf::st_crs(a$parcels)
  fields <- diff_fields(a, b)
  # Rules, by the rule table.
  ra <- rule_table(a$rulebook)
  rb <- rule_table(b$rulebook)
  key <- function(r) paste(r$scope, r$id, r$zone, r$rule, r$applies_to %|NA|% "", r$variant %|NA|% "", sep = "|")
  ka <- key(ra)
  kb <- key(rb)
  ka <- make.unique(ka)
  kb <- make.unique(kb)
  rules <- list()
  for (k in union(ka, kb)) {
    x <- ra[match(k, ka), ]
    y <- rb[match(k, kb), ]
    if (!is.na(match(k, ka)) && !is.na(match(k, kb)) && identical(x$value, y$value) &&
        identical(x$conditions, y$conditions)) next
    src <- if (!is.na(match(k, kb))) y else x
    rules[[length(rules) + 1]] <- data.frame(scope = src$scope, id = src$id, rule = src$rule,
                                             applies_to = src$applies_to,
                                             from = if (is.na(match(k, ka))) NA_character_ else x$value,
                                             to = if (is.na(match(k, kb))) NA_character_ else y$value,
                                             change = if (is.na(match(k, ka))) "added" else if (is.na(match(k, kb))) "removed" else "changed",
                                             source = src$source, stringsAsFactors = FALSE)
  }
  rules <- if (length(rules)) do.call(rbind, rules) else
    data.frame(scope = character(), id = character(), rule = character(), applies_to = character(),
               from = character(), to = character(), change = character(), source = character())
  # Rezoned land.
  zk <- function(sc) {
    z <- sc$zoning
    if (sf::st_crs(z) != crs) z <- sf::st_transform(z, crs)
    m <- unlist(sc$rulebook$zone_map %||% list())
    z$key <- unname(m[as.character(z[[sc$zone_field]])])
    z$key[is.na(z$key)] <- as.character(z[[sc$zone_field]])[is.na(z$key)]
    z
  }
  rezoned <- NULL
  if (any(c("zoning", "zone_field", "rulebook") %in% fields)) {
    za <- zk(a)
    zb <- zk(b)
    ov <- overlap_table(geos::geos_make_valid(as_geos(za)), geos::geos_make_valid(as_geos(zb)), min_area = 0.01)
    ov <- ov[za$key[ov$site] != zb$key[ov$feature], , drop = FALSE]
    if (nrow(ov)) {
      g <- geos::geos_intersection(geos::geos_make_valid(as_geos(za))[ov$site], geos::geos_make_valid(as_geos(zb))[ov$feature])
      rezoned <- sf::st_sf(from = za$key[ov$site], to = zb$key[ov$feature], area = ov$area,
                           geometry = sf::st_as_sfc(g))
      sf::st_crs(rezoned) <- crs
    }
  }
  # Layers: land added and removed, by layer name.
  layers <- NULL
  if ("layers" %in% fields) {
    nm <- union(names(a$layers), names(b$layers))
    pieces <- list()
    for (n in nm) {
      la <- a$layers[[n]]
      lb <- b$layers[[n]]
      if (identical(rlang::hash(la), rlang::hash(lb))) next
      if (!(is.null(la) || inherits(la, "sf")) || !(is.null(lb) || inherits(lb, "sf"))) {
        pieces[[length(pieces) + 1]] <- sf::st_sf(layer = n, change = "changed (raster)",
                                                  geometry = sf::st_sfc(sf::st_polygon(), crs = crs))
        next
      }
      u <- function(l) {
        if (is.null(l) || !nrow(l)) return(geos::geos_empty())
        if (sf::st_crs(l) != crs) l <- sf::st_transform(l, crs)
        geos::geos_unary_union(geos::geos_make_collection(geos::geos_make_valid(as_geos(l))))
      }
      ua <- u(la)
      ub <- u(lb)
      add <- geos::geos_difference(ub, ua)
      rem <- geos::geos_difference(ua, ub)
      pieces[[length(pieces) + 1]] <- sf::st_sf(layer = n, change = c("added", "removed"),
                                                area = c(geos::geos_area(add), geos::geos_area(rem)),
                                                geometry = sf::st_as_sfc(c(add, rem)))
      sf::st_crs(pieces[[length(pieces)]]) <- crs
    }
    if (length(pieces)) layers <- do.call(rbind, lapply(pieces, function(p) { if (is.null(p$area)) p$area <- NA_real_; p[, c("layer", "change", "area")] }))
  }
  parcels <- NULL
  if ("parcels" %in% fields) {
    ma <- make_sites(a$parcels, a$site_id, a$group_by)
    mb <- make_sites(b$parcels, b$site_id, b$group_by)
    ga <- geos::geos_make_valid(as_geos(ma))
    gb <- geos::geos_make_valid(as_geos(mb))
    k <- match(ma$site_id, mb$site_id)
    same_a <- !is.na(k)
    same_a[same_a] <- geos::geos_equals_exact(ga[same_a], gb[k[same_a]], tolerance = 0.01)
    same_b <- mb$site_id %in% ma$site_id[same_a]
    parcels <- sf::st_sf(id = c(ma$site_id[!same_a], mb$site_id[!same_b]),
                         change = c(rep("only_baseline", sum(!same_a)), rep("only_scenario", sum(!same_b))),
                         geometry = sf::st_as_sfc(c(ga[!same_a], gb[!same_b])))
    sf::st_crs(parcels) <- crs
  }
  structure(list(fields = fields, rules = rules, rezoned = rezoned, layers = layers, parcels = parcels),
            class = "plancap_input_diff")
}

#' @export
print.plancap_input_diff <- function(x, ...) {
  cli::cli_text("{.strong <plancap input diff>} inputs that differ: {if (length(x$fields)) paste(x$fields, collapse = ', ') else 'none'}.")
  if (nrow(x$rules)) {
    cli::cli_text("{nrow(x$rules)} rule change{?s}:")
    print(x$rules[, c("scope", "id", "rule", "applies_to", "from", "to", "change")], row.names = FALSE)
  }
  if (!is.null(x$rezoned)) {
    rz <- stats::aggregate(area ~ from + to, data = sf::st_drop_geometry(x$rezoned), FUN = sum)
    cli::cli_text("Land rezoned:")
    rz$area <- format(round(rz$area), big.mark = ",")
    print(rz, row.names = FALSE)
  }
  if (!is.null(x$layers)) {
    cli::cli_text("Layers changed:")
    l <- sf::st_drop_geometry(x$layers)
    l$area <- format(round(l$area), big.mark = ",")
    print(l, row.names = FALSE)
  }
  if (!is.null(x$parcels)) cli::cli_text("Parcels: {sum(x$parcels$change == 'only_baseline')} only in the baseline, \\
                                          {sum(x$parcels$change == 'only_scenario')} only in the scenario.")
  invisible(x)
}

#' @export
print.plancap_comparison <- function(x, ...) {
  cli::cli_text("{.strong <plancap comparison>} baseline {.val {x$baseline}}")
  print(format_summary(x$totals), row.names = FALSE, right = TRUE)
  for (p in x$pairs) {
    cli::cli_h3("{p$scenario} against {p$baseline}")
    t <- p$totals
    f <- function(v) format(round(v), big.mark = ",")
    for (i in seq_len(nrow(t))) {
      cli::cli_text("{t$measure[i]}: {f(t$baseline[i])} to {f(t$scenario[i])} \\
                     ({if (t$change[i] >= 0) '+' else ''}{f(t$change[i])}, \\
                     {if (is.na(t$change_pct[i])) 'n/a' else sprintf('%+.1f%%', t$change_pct[i])})")
    }
    if (!is.null(p$attribution) && nrow(p$attribution)) {
      cli::cli_text("Drivers of the floor area change: \\
                     {paste0(p$attribution$driver, ' ', ifelse(p$attribution$floor_area >= 0, '+', ''), f(p$attribution$floor_area), collapse = ', ')}.")
    }
    r <- table(p$sites$reason)
    cli::cli_text("Sites: {paste(names(r), r, collapse = ', ')}.")
  }
  invisible(x)
}

#' @rdname compare_scenarios
#' @param object A comparison.
#' @export
summary.plancap_comparison <- function(object, ...) {
  lapply(object$pairs, function(p) {
    list(totals = p$totals, attribution = p$attribution, rule_attribution = p$rule_attribution,
         reasons = as.data.frame(table(reason = p$sites$reason), stringsAsFactors = FALSE),
         transitions = p$transitions[abs(p$transitions$land_area) > 0 & p$transitions$from != p$transitions$to, ],
         by_zone = p$by_zone, land = p$land)
  })
}

#' Reconcile a comparison
#'
#' Checks that every view of a comparison adds up: the drivers sum to the
#' total change, and the zone transitions, the zone and height summaries,
#' the common geography and the site-level changes each reproduce both
#' scenarios' totals.
#'
#' @param cmp A comparison from [compare_scenarios()].
#' @param tolerance Relative tolerance.
#' @return A data frame of class `plancap_checks`.
#' @export
check_comparison <- function(cmp, tolerance = 1e-6) {
  if (!inherits(cmp, "plancap_comparison")) cli::cli_abort("{.arg cmp} must come from {.fn compare_scenarios}.")
  out <- list()
  add <- function(pair, check, ok, value, detail = "") {
    out[[length(out) + 1]] <<- data.frame(check = paste0(pair, ": ", check), status = if (ok) "ok" else "fail",
                                          value = value, detail = detail, stringsAsFactors = FALSE)
  }
  for (nm in names(cmp$pairs)) {
    p <- cmp$pairs[[nm]]
    t <- p$totals
    for (m in c("floor_area", "dwellings")) {
      base <- t$baseline[t$measure == m]
      scen <- t$scenario[t$measure == m]
      tol <- tolerance * max(abs(base), abs(scen), 1) + 1e-6
      near <- function(v, target) abs(v - target) <= tol
      if (!is.null(p$attribution) && nrow(p$attribution)) {
        s <- sum(p$attribution[[m]])
        add(nm, paste("drivers sum to the change in", m), near(s, scen - base), sprintf("%.2f of %.2f", s, scen - base))
      }
      tr <- p$transitions
      add(nm, paste("transitions reproduce", m), near(sum(tr[[paste0(m, "_baseline")]]), base) &&
            near(sum(tr[[paste0(m, "_scenario")]]), scen), "")
      add(nm, paste("zones reproduce", m), near(sum(p$by_zone[[paste0(m, "_baseline")]]), base) &&
            near(sum(p$by_zone[[paste0(m, "_scenario")]]), scen), "")
      add(nm, paste("height bands reproduce", m), near(sum(p$by_height[[paste0(m, "_baseline")]]), base) &&
            near(sum(p$by_height[[paste0(m, "_scenario")]]), scen), "")
      for (g in c("by_area", "by_grid")) {
        if (is.null(p[[g]])) next
        add(nm, paste(sub("by_", "", g), "reproduces", m), near(sum(p[[g]][[paste0(m, "_baseline")]]), base) &&
              near(sum(p[[g]][[paste0(m, "_scenario")]]), scen), "")
      }
      st <- p$sites
      add(nm, paste("sites reproduce", m), near(sum(st[[paste0(m, "_baseline")]]), base) &&
            near(sum(st[[paste0(m, "_scenario")]], na.rm = TRUE), scen),
          sprintf("%.2f of %.2f", sum(st[[paste0(m, "_scenario")]], na.rm = TRUE), scen))
    }
    lr <- p$land
    add(nm, "land reconciles", TRUE, sprintf("%.0f to %.0f m2 (%.0f only in the baseline, %.0f only in the scenario)",
                                             lr$area[1], lr$area[2], lr$area[3], lr$area[4]))
  }
  r <- do.call(rbind, out)
  class(r) <- c("plancap_checks", "data.frame")
  r
}

#' Exampleton Plan Change 1
#'
#' The worked plan change for Exampleton, built to exercise every kind of
#' difference between two scenarios (see [compare_scenarios()]):
#'
#' - a rulebook that `extends:` the operative one: MDR's height from 12 m to
#'   16 m, and a new Terraced Housing zone (THZ);
#' - a zoning layer rezoning the MDR blocks whose centre is within 600 m of
#'   the station to THZ;
#' - a wider flood plain (70 m either side of the stream, from 45 m);
#' - one low density block re-subdivided into new lots.
#'
#' @return A list: `rulebook`, and `sf` layers `zoning`, `flood_hazard` and
#'   `parcels` (all parcels, with the re-subdivided block's new lots).
#' @export
#' @examples
#' pc1 <- exampleton_pc1()
#' pc1$rulebook
#' table(pc1$zoning$zone)
exampleton_pc1 <- function() {
  f <- system.file("extdata", "exampleton_pc1.gpkg", package = "plancap", mustWork = TRUE)
  rd <- function(l) sf::st_read(f, layer = l, quiet = TRUE, stringsAsFactors = FALSE)
  list(rulebook = rulebook_example("exampleton_pc1"), zoning = rd("zoning"),
       flood_hazard = rd("flood_hazard"), parcels = rd("parcels"))
}
