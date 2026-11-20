#' Estimate plan-enabled capacity
#'
#' Turns each site's building envelope into floor area (residential and
#' business) and dwellings, by the path its zone's method sets:
#'
#' * **volumetric**: floor area from the envelope, split between residential
#'   and business by the zone's `use`, and residential floor area converted to
#'   dwellings by the rulebook's [conversion()];
#' * **density**: dwellings straight from the density rule (dwellings per
#'   hectare, land per dwelling, or the vacant-site minimum), at least one on
#'   an existing lot;
#' * **hybrid**: both, the lesser counts;
#' * **large sites** (at least `defaults$large_site$threshold`): dwellings by
#'   the land less the infrastructure deduction over a land area per dwelling,
#'   where the rulebook gives one (`large_site$method = "divisor"`, or any
#'   density zone); envelope sites over the threshold take the deduction on
#'   their envelope's dwellings.
#'
#' Then, in this order: floor area ratio and maximum site floorspace (capping
#' the stack from the ground up), no dwellings on a site whose envelope holds
#' no floor (unless a water yard emptied it) or whose land overlays removed,
#' maximum dwellings per site, the access width cap, minor dwellings (their
#' own column), area totals (a precinct's dwelling cap), and entitlements (a
#' minimum guaranteed by law, applied as a floor). Bonuses are reported apart,
#' in `*_with_bonus` columns.
#'
#' Results are **plan-enabled, gross, blank-slate**: what the rules allow if no
#' buildings existed, before feasibility or take-up.
#'
#' @param x A [scenario()].
#' @param envelope Optional envelope from [build_envelopes()] for `x`, to
#'   avoid rebuilding it.
#' @param baseline Optional earlier `plancap_capacity`: sites whose inputs are
#'   unchanged are copied (see [build_envelopes()]).
#' @param conversion Optional [conversion()] overriding the rulebook's.
#' @param ... Passed to [build_envelopes()].
#' @return A `plancap_capacity` object: `sites` (`sf`, one row per site, every
#'   site kept, with floor area, dwellings, the path and binding constraints
#'   and flags), `stack` (per storey, with the residential and business
#'   split), the `envelope`, the `rulebook`, the `conversion` used and a
#'   `report`.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'   parcels = town$parcels[town$parcels$parcel_type == "land", ][1:80, ],
#'   roads = town$parcels[town$parcels$parcel_type == "road", ],
#'   zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' cap <- estimate_capacity(sc)
#' cap
estimate_capacity <- function(x, envelope = NULL, baseline = NULL, conversion = NULL, ...) {
  if (!inherits(x, "plancap_scenario")) cli::cli_abort("{.arg x} must be a {.fn scenario}.")
  rb <- x$rulebook
  conv <- if (!is.null(conversion)) unclass(conversion) else rb$conversion
  if (is.null(conv)) {
    cli::cli_abort(c("The rulebook has no floor area to dwellings conversion.",
                     "i" = "Add one with {.fn set_conversion}, or pass {.arg conversion}."))
  }
  prep <- prepare_sites(x)
  if (is.null(envelope)) {
    envelope <- build_envelopes(x, include_density = TRUE,
                                baseline = if (!is.null(baseline)) baseline$envelope, ...)
  }
  dflt <- utils::modifyList(rulebook_defaults(), rb$defaults %||% list())
  res <- resolve_sites(prep, rb)
  s <- sf::st_drop_geometry(prep$sites)
  ev <- envelope$sites[match(s$site_id, envelope$sites$site_id), ]
  params <- res$params
  pz <- lapply(res$param_id, function(p) if (is.na(p)) NULL else params[[p]])
  method <- vapply(pz, function(z) z$method %||% NA_character_, "")
  report <- list()

  # ---- Floor area: caps on the whole stack, then the use split ---------------
  st <- envelope$stack
  st <- cap_stack_total(st, s, pz, envelope)
  st <- split_use(st, s, pz)
  f <- factor(st$site_id, levels = s$site_id)
  sum_by <- function(v) {
    out <- as.vector(tapply(v, f, sum))
    out[is.na(out)] <- 0
    out
  }
  floor_area <- sum_by(st$enabled_area)
  res_area <- sum_by(st$residential_area)
  bus_area <- sum_by(st$business_area)

  # ---- Dwellings by path --------------------------------------------------------
  area <- s$area
  removed <- ev$removed_area %||% rep(0, nrow(s))
  removed[is.na(removed)] <- 0
  land <- pmax(0, area - removed)
  ls_d <- dflt$large_site
  threshold <- ls_d$threshold %||% Inf
  deduction <- ls_d$deduction %||% 0
  by_divisor <- identical(ls_d$method, "divisor")
  ls_div <- vapply(pz, function(z) z$density$large_site$area_per_dwelling %||% NA_real_, 0)
  over <- !is.na(area) & area >= threshold & !is.na(ls_div)
  vol_zone <- method %in% c("volumetric", "hybrid")
  is_large <- over & (!vol_zone | by_divisor)
  is_density <- method %in% "density" & !is_large
  is_vol <- !is.na(method) & method != "none" & !is_large & !is_density

  path <- ifelse(is_large, "large_site", ifelse(is_density, "density",
                 ifelse(is_vol, "volumetric", NA_character_)))
  binding <- rep(NA_character_, nrow(s))
  dwell <- rep(0, nrow(s))

  d_den <- density_dwellings(pz, land)
  if (any(is_density)) {
    dwell[is_density] <- d_den$n[is_density]
    binding[is_density] <- d_den$binding[is_density]
  }
  if (any(is_large)) {
    dwell[is_large] <- floor(land[is_large] * (1 - deduction) / ls_div[is_large])
    binding[is_large] <- "large_site_subdivision"
  }
  min_size <- vapply(pz, function(z) z$density$min_dwelling_size %||% NA_real_, 0)
  d_vol <- floor_to_dwellings(res_area, conv, min_size)
  if (any(is_vol)) {
    dwell[is_vol] <- d_vol[is_vol]
    binding[is_vol] <- "floor_area"
  }
  hybrid <- method %in% "hybrid" & is_vol
  take <- hybrid & !is.na(d_den$n) & d_den$n < dwell
  dwell[take] <- d_den$n[take]
  binding[take] <- d_den$binding[take]
  path[take] <- "hybrid_density"
  # A large envelope site counts dwellings after the same allowance for roads
  # and reserves the divisor makes; floor area keeps the whole envelope.
  env_large <- over & !is_large & path %in% "volumetric"
  if (deduction > 0 && any(env_large)) dwell[env_large] <- floor(dwell[env_large] * (1 - deduction))

  # No buildable envelope: no dwelling, unless a water yard emptied the lot.
  sub_path <- path %in% c("density", "hybrid_density", "large_site")
  no_env <- sub_path & ev$floor_area %in% 0 & !(ev$water_yard_share %||% rep(0, nrow(s)) >= 0.5)
  dwell[no_env] <- 0
  binding[no_env] <- "no_buildable_envelope"
  gone <- sub_path & removed > 0 & land < dflt$min_floorplate
  dwell[gone] <- 0
  binding[gone] <- "overlay_exclusion"

  # Dwellings per site, access width.
  mx <- vapply(pz, function(z) z$density$max_dwellings_per_site %||% NA_real_, 0)
  cut <- !is.na(mx) & dwell > mx
  dwell[cut] <- mx[cut]
  binding[cut] <- "max_dwellings_per_site"
  acc <- access_width_cap(pz, s)
  cut <- !is.na(acc) & dwell > acc
  dwell[cut] <- acc[cut]
  binding[cut] <- "access_width"

  minor <- vapply(pz, function(z) z$density$minor_dwellings_per_site %||% 0, 0)
  minor <- ifelse(path %in% c("density", "hybrid_density") & dwell > 0, minor * dwell, 0)

  # Area totals: a precinct's (or sub-area group's) dwelling cap, shared in
  # proportion.
  tot <- area_totals(dwell, s, prep, rb)
  dwell <- tot$dwellings
  binding[tot$capped] <- "area_total"
  report$area_totals_applied <- tot$applied

  # Entitlements: a minimum guaranteed whatever the local rules say, on sites
  # that can build at all.
  ent <- entitlements(dwell, s, rb, prep, can_build = floor_area > 0 | sub_path)
  binding[ent$raised] <- "entitlement"
  dwell <- ent$dwellings

  # Bonuses, reported apart.
  bon <- bonuses(dwell, floor_area, res_area, s, pz, rb, prep, conv, min_size)

  out <- prep$sites[, "site_id"]
  out$parent_id <- s$parent_id
  out$zone_key <- s$zone_key
  out$zone_code <- s$zone_code
  out$area <- area
  out$net_area <- s$net_area
  out$method <- method
  out$path <- path
  out$variant <- ev$variant
  out$storeys <- ev$storeys
  out$height <- ev$height
  out$footprint <- ev$footprint
  out$floor_area <- floor_area
  out$residential_floor_area <- res_area
  out$business_floor_area <- bus_area
  out$dwellings <- as.integer(dwell)
  out$minor_dwellings <- as.integer(minor)
  out$floor_area_with_bonus <- bon$floor_area
  out$dwellings_with_bonus <- as.integer(bon$dwellings)
  out$envelope_binding <- ev$binding
  out$dwelling_binding <- binding
  out$removed_area <- removed
  out$flag <- ifelse(is.na(s$zone_key), "no_zone",
              ifelse(is.na(method), "no_rules",
              ifelse(method %in% "none", "no_capacity_zone",
              ifelse(floor_area == 0 & dwell == 0, "no_capacity", "ok"))))
  report$envelope <- envelope$report
  structure(list(sites = out, stack = st, envelope = envelope, rulebook = rb,
                 conversion = conv, scenario = x$name, report = report),
            class = "plancap_capacity")
}

# Floor area ratio and maximum site floorspace cap the stack's total from the
# ground up: lower storeys keep their area, the top ones give it up.
cap_stack_total <- function(st, s, pz, envelope) {
  if (!nrow(st)) return(st)
  st <- st[order(st$site_id, st$storey), , drop = FALSE]
  i <- match(st$site_id, s$site_id)
  far <- vapply(pz, function(z) {
    r <- z$ratios$far_max
    if (is.null(r)) NA_real_ else if (is.numeric(r)) r else if (is.numeric(r$value)) r$value else NA_real_
  }, 0)
  msf <- vapply(pz, function(z) z$form$max_site_floorspace %||% NA_real_, 0)
  cap <- pmin(far * s$area, msf, na.rm = TRUE)
  cum_before <- stats::ave(st$enabled_area, st$site_id, FUN = function(v) c(0, utils::head(cumsum(v), -1)))
  allowed <- pmax(0, cap[i] - cum_before)
  bind <- !is.na(allowed) & allowed < st$enabled_area - 1e-9
  st$binding[bind] <- ifelse(!is.na(far[i][bind]) & far[i][bind] * s$area[i][bind] <= msf[i][bind] %|NA|% Inf,
                             "far", "max_site_floorspace")
  st$enabled_area[bind] <- allowed[bind]
  st[st$enabled_area > 0 | !bind, , drop = FALSE]
}

# Residential and business floor area per storey, from the zone's use and
# residential share (a number or bands by storey); floor area over land where
# an overlay keeps dwellings out is business where the zone allows it.
split_use <- function(st, s, pz) {
  st$residential_area <- 0
  st$business_area <- 0
  if (!nrow(st)) return(st)
  i <- match(st$site_id, s$site_id)
  for (k in unique(i)) {
    rows <- which(i == k)
    z <- pz[[k]]
    u <- z$use %||% list()
    res_ok <- !isFALSE(u$residential)
    bus_ok <- isTRUE(u$business)
    share <- u$residential_share
    sh <- if (is.null(share)) (if (res_ok && !bus_ok) 1 else if (!res_ok) 0 else 1)
          else resolve_ratio(share, list(storey = st$storey[rows]))
    sh <- rep_len(sh, length(rows))
    if (!res_ok) sh[] <- 0
    ea <- st$enabled_area[rows]
    ra <- ea * sh
    ba <- if (bus_ok) ea * (1 - sh) else rep(0, length(rows))
    rex <- st$residential_excluded[rows] %||% 0
    frac <- ifelse(st$clipped_area[rows] > 0, pmin(1, rex / st$clipped_area[rows]), 0)
    moved <- ra * frac
    ra <- ra - moved
    if (bus_ok) ba <- ba + moved else st$enabled_area[rows] <- ea - moved
    st$residential_area[rows] <- ra
    st$business_area[rows] <- ba
  }
  st
}

# Dwellings from a density rule: dwellings per hectare (or land per dwelling),
# else the vacant-site minimum with at least one dwelling on an existing lot.
density_dwellings <- function(pz, land) {
  n <- rep(NA_real_, length(pz))
  binding <- rep("no_density_rule", length(pz))
  for (k in seq_along(pz)) {
    d <- pz[[k]]$density
    if (is.null(d)) next
    dph <- d$dwellings_per_ha %||% (if (!is.null(d$site_area_per_dwelling) && d$site_area_per_dwelling > 0)
      10000 / d$site_area_per_dwelling)
    if (!is.null(dph) && dph > 0) {
      n[k] <- floor(land[k] / 10000 * dph + 1e-9)
      binding[k] <- "density"
    } else {
      mn <- d$vacant_site_min_area %||% d$min_site_area
      if (!is.null(mn) && mn > 0) {
        n[k] <- max(1, floor(land[k] / mn))
        binding[k] <- "vacant_site_minimum"
      }
    }
  }
  list(n = n, binding = binding)
}

# Residential floor area to dwellings: floor area times efficiency over the
# dwelling size (or the unit mix's average size); a site with at least the
# minimum floor area counts one.
floor_to_dwellings <- function(res_area, conv, min_size = NA) {
  size <- conv$dwelling_size %||%
    sum(vapply(conv$unit_mix, function(u) u$size * u$share, 0))
  eff <- conv$efficiency %||% 1
  n <- floor(res_area * eff / size + 1e-9)
  if (isTRUE(conv$min_one_dwelling)) {
    floor1 <- conv$min_one_dwelling_floor %||% min_size
    floor1 <- rep_len(floor1, length(n))
    one <- n < 1 & !is.na(floor1) & res_area >= floor1 & res_area > 0
    n[one] <- 1
  }
  n
}

# The access width table: frontage (or the access leg's width at the road)
# to the most dwellings it may serve.
access_width_cap <- function(pz, s) {
  out <- rep(NA_real_, length(pz))
  for (k in seq_along(pz)) {
    tab <- pz[[k]]$density$access_width
    if (is.null(tab)) next
    f <- s$frontage[k]
    if (is.na(f)) next
    for (b in tab) {
      if (f >= (b$min %||% 0) && f < (b$max %||% Inf)) {
        out[k] <- b$max_dwellings %||% NA_real_
        break
      }
    }
  }
  out
}

area_totals <- function(dwell, s, prep, rb) {
  capped <- rep(FALSE, length(dwell))
  applied <- 0L
  ar <- prep$areas
  ar <- ar[ar$share >= 0.5, , drop = FALSE]
  groups <- list()
  for (a in names(rb$areas)) {
    def <- rb$areas[[a]]
    rows <- ar[ar$area == a, , drop = FALSE]
    if (!nrow(rows)) next
    if (!is.null(def$totals$max_dwellings)) {
      groups[[length(groups) + 1]] <- list(sites = unique(rows$site_id), cap = def$totals$max_dwellings)
    }
    for (sk in names(def$sub_areas)) {
      sa <- def$sub_areas[[sk]]
      mxd <- sa$totals$max_dwellings
      if (is.null(mxd)) next
      members <- if (!is.null(sa$total_group)) {
        subs <- names(Filter(function(x) identical(x$total_group, sa$total_group), def$sub_areas))
        unique(rows$site_id[toupper(rows$sub_area) %in% toupper(subs)])
      } else unique(rows$site_id[toupper(rows$sub_area) == toupper(sk)])
      groups[[length(groups) + 1]] <- list(sites = members, cap = mxd)
    }
  }
  for (g in unique(groups)) {
    i <- match(g$sites, s$site_id)
    tot <- sum(dwell[i])
    if (tot > g$cap && tot > 0) {
      dwell[i] <- floor(dwell[i] * g$cap / tot)
      capped[i] <- TRUE
      applied <- applied + 1L
    }
  }
  list(dwellings = dwell, capped = capped, applied = applied)
}

site_meets <- function(when, s, prep) {
  if (is.null(when)) return(rep(TRUE, nrow(s)))
  ok <- rep(TRUE, nrow(s))
  if (!is.null(when$distance_to)) {
    d <- prep$distances[prep$distances$layer == when$distance_to, ]
    dd <- d$distance[match(s$site_id, d$site_id)]
    if (!is.null(when$max_distance)) ok <- ok & !is.na(dd) & dd <= when$max_distance
    if (!is.null(when$min_distance)) ok <- ok & !is.na(dd) & dd >= when$min_distance
  }
  if (!is.null(when$min_site_area)) ok <- ok & s$area >= when$min_site_area
  if (!is.null(when$max_site_area)) ok <- ok & s$area < when$max_site_area
  ok
}

entitlements <- function(dwell, s, rb, prep, can_build) {
  raised <- rep(FALSE, length(dwell))
  for (e in rb$entitlements) {
    if (!identical(e$quantity, "dwellings")) next
    hit <- (is.null(e$applies_to_zones) | s$zone_key %in% e$applies_to_zones) &
      site_meets(e$when, s, prep) & can_build & dwell < e$value
    dwell[hit] <- e$value
    raised[hit] <- TRUE
  }
  list(dwellings = dwell, raised = raised)
}

# Bonuses: floor area ratio, floor area and dwelling bonuses, reported in
# separate columns. Height bonuses need a second envelope and are reported as
# not yet evaluated.
bonuses <- function(dwell, floor_area, res_area, s, pz, rb, prep, conv, min_size) {
  fa <- floor_area
  dw <- dwell
  for (b in rb$bonuses) {
    hit <- (is.null(b$applies_to_zones) | s$zone_key %in% b$applies_to_zones) & site_meets(b$when, s, prep)
    if (!any(hit) || !is.numeric(b$value)) next
    if (b$quantity %in% c("far", "floor_area")) {
      add <- if (b$quantity == "far") b$value * s$area else b$value
      new <- if (b$combine == "multiply") fa * b$value else fa + add
      if (!is.null(b$cap)) new <- pmin(new, b$cap * (if (b$quantity == "far") s$area else 1))
      # Extra floor area counts only up to what the envelope can hold above the
      # ratio cap; without the uncapped envelope this is an upper bound.
      share <- ifelse(floor_area > 0, res_area / floor_area, 0)
      fa[hit] <- new[hit]
      dw[hit] <- floor_to_dwellings(fa[hit] * share[hit], conv, min_size[hit])
    } else if (b$quantity == "dwellings") {
      new <- if (b$combine == "multiply") floor(dw * b$value) else dw + b$value
      dw[hit] <- new[hit]
    }
  }
  list(floor_area = fa, dwellings = dw)
}

#' @export
print.plancap_capacity <- function(x, ...) {
  s <- x$sites
  cli::cli_text("{.strong <plancap capacity>} {x$scenario}: {nrow(s)} sites, \\
                 {format(round(sum(s$floor_area)), big.mark = ',')} m2 floor area \\
                 ({format(round(sum(s$residential_floor_area)), big.mark = ',')} m2 residential), \\
                 {format(sum(s$dwellings), big.mark = ',')} dwellings \\
                 (+{format(sum(s$minor_dwellings), big.mark = ',')} minor).")
  conv <- x$conversion
  size <- conv$dwelling_size %||% round(sum(vapply(conv$unit_mix, function(u) u$size * u$share, 0)))
  cli::cli_text("{.emph Plan-enabled, gross, blank-slate capacity; dwellings at {size} m2 \\
                 and {round(100 * (conv$efficiency %||% 1))}% efficiency.}")
  p <- table(s$path, useNA = "no")
  if (length(p)) cli::cli_text("Paths: {paste(names(p), p, collapse = ', ')}.")
  bonus <- sum(s$dwellings_with_bonus) - sum(s$dwellings)
  if (bonus > 0) cli::cli_text("With bonuses: +{format(bonus, big.mark = ',')} dwellings.")
  invisible(x)
}
