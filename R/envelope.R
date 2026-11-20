#' Build the storey-by-storey building envelope of every site
#'
#' The core of the engine: a stack of storey footprints per site, each the
#' site's buildable ground clipped back from every boundary by every rule that
#' applies at that storey's height, then capped by coverage, landscaping and
#' floorplate limits.
#'
#' @section Method:
#' Carried over from capacityengine, where each choice was tested:
#' * **Loop over storeys, vectorise over sites.** At each storey every live
#'   site is handled in one set of GEOS calls.
#' * **One setback per boundary per storey.** Yards, recession planes,
#'   upper-level and proportional setbacks all say "at this height, stand this
#'   far back from this boundary", so the binding distance on a boundary is the
#'   largest any applicable rule asks, and the clip is a single buffer at that
#'   distance.
#' * **A storey is tested at its ceiling** (`level_reference = "ceiling"`): the
#'   whole storey must fit under a plane.
#' * **A zone's storey height is its own** (stated height over stated storeys),
#'   and does not change when an overlay changes the site's height.
#' * **Coverage and landscaping are shares of net site area**, not of the
#'   clipped envelope, and the most restrictive applies (PLAN 3.5).
#' * **The stack never widens going up**, and a storey smaller than the
#'   minimum floorplate ends it.
#' * **Reflex corners are filled** with wedges, so a bend in a boundary away
#'   from the site leaves no hairline teeth; parts smaller than a floorplate are
#'   dropped.
#' * **Alternative standards are evaluated separately** and each site takes
#'   the most enabling (`variant_choice = "max"`), or as the rulebook says.
#'
#' A rule whose condition cannot be evaluated is not guessed at: a positive
#' trigger (`adjacent_zones`, `facing`, a road width) is not applied, which
#' overstates; an exemption (`not_adjacent_zones`) is not applied, so the rule
#' bites, which understates. Both are counted in the run report.
#'
#' Water yards (setbacks naming `riparian`, `coastal` or `lakeside`) are
#' measured from the water features themselves, and the land within reach is
#' taken off the buildable ground.
#'
#' @section Incremental runs:
#' Each site's result carries a signature of everything that determines it:
#' its geometry and boundaries, its effective rules and the run settings.
#' Given a `baseline` envelope, sites whose signature is unchanged are copied
#' from it rather than recomputed, so a plan change that touches a tenth of
#' the sites costs about a tenth of a run. The result is identical to a full
#' run.
#'
#' @param x A [scenario()], or sites from [prepare_sites()] (then give
#'   `rulebook`).
#' @param rulebook The rulebook, when `x` is prepared sites.
#' @param variant_choice Overrides the rulebook's `variant_choice`.
#' @param include_density Also build envelopes for density-method zones.
#' @param keep_geometry Keep each storey's footprint polygon.
#' @param keep_setbacks Keep, for every boundary at every storey, the setback
#'   applied and the rule (and citation) that set it. One row per boundary per
#'   storey, so meant for a few sites, not a region.
#' @param baseline An earlier `plancap_envelope` to copy unchanged sites from.
#' @param max_storeys Guard against a runaway height (not a plan rule).
#' @param height_add Optional named numeric vector, by site id: metres of
#'   extra height (as a height bonus gives), added to total and occupiable
#'   height.
#' @return A `plancap_envelope`: a list with `stack` (one row per site and
#'   storey of the chosen variant), `sites` (one row per site: variant, storeys,
#'   height reached, footprint, floor area, the constraint that bound most),
#'   `variants` (every variant's total, per site), optional `geometry` and
#'   `setbacks`, a `report` and the per-site `signatures`.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'   parcels = town$parcels[town$parcels$parcel_type == "land", ][1:60, ],
#'   roads = town$parcels[town$parcels$parcel_type == "road", ],
#'   zoning = town$zoning, layers = town["height_areas"])
#' env <- build_envelopes(sc)
#' env
#' head(env$sites)
build_envelopes <- function(x, rulebook = NULL, variant_choice = NULL, include_density = FALSE,
                            keep_geometry = FALSE, keep_setbacks = FALSE, baseline = NULL,
                            max_storeys = 60, height_add = NULL) {
  layers <- list()
  if (inherits(x, "plancap_scenario")) {
    rulebook <- x$rulebook
    layers <- x$layers
    prep <- prepare_sites(x)
  } else if (inherits(x, "plancap_sites")) {
    check_rulebook(rulebook)
    prep <- x
  } else {
    cli::cli_abort("{.arg x} must be a {.fn scenario} or prepared sites.")
  }
  rb <- rulebook
  if (!is.null(baseline) && !inherits(baseline, "plancap_envelope")) {
    cli::cli_abort("{.arg baseline} must be a {.cls plancap_envelope}.")
  }
  choice <- variant_choice %||% rb$variant_choice %||% "max"
  dflt <- utils::modifyList(rulebook_defaults(), rb$defaults %||% list())
  settings <- list(level_reference = dflt$level_reference, min_floorplate = dflt$min_floorplate,
                   terrain = dflt$terrain %||% "stepped", max_ground_slope = dflt$max_ground_slope %||% 0.5,
                   include_density = include_density, choice = choice, max_storeys = max_storeys,
                   defaults = dflt, morphology = prep$morphology,
                   ground_mode = rb$ground$mode %||% "most_restrictive",
                   version = as.character(utils::packageVersion("plancap")))

  excl <- exclusion_layers(rb, layers, sf::st_crs(prep$sites))
  settings$exclusion_hash <- rlang::hash(lapply(excl, function(e) wk::as_wkb(e$geom)))
  surf <- sample_surfaces(prep, rb, layers, dflt)
  mods <- surf$mods
  if (!is.null(height_add) && length(height_add)) {
    mods <- rbind(mods, data.frame(site_id = names(height_add), what = "height_add",
                                   value = as.numeric(height_add), stringsAsFactors = FALSE))
  }
  res <- resolve_sites(prep, rb, mods)
  sites <- prep$sites
  s_df <- sf::st_drop_geometry(sites)
  sig <- site_signatures(prep, res, settings, surf$bands)

  todo <- seq_len(nrow(sites))
  copied <- integer()
  if (!is.null(baseline)) {
    same <- !is.na(sig) & sig == baseline$signatures[sites$site_id]
    copied <- which(same %in% TRUE)
    todo <- setdiff(todo, copied)
  }
  core <- envelope_core(prep, res, rb, settings, idx = todo, excl = excl, bands = surf$bands,
                        keep_geometry = keep_geometry,
                        keep_setbacks = keep_setbacks)
  if (length(copied)) {
    ids <- sites$site_id[copied]
    core$stack <- rbind(core$stack, baseline$stack[baseline$stack$site_id %in% ids, names(core$stack)])
    core$variants <- rbind(core$variants, baseline$variants[baseline$variants$site_id %in% ids, names(core$variants)])
    if (is.null(core$removed)) core$removed <- stats::setNames(rep(0, nrow(sites)), sites$site_id)
    core$removed[ids] <- baseline$sites$removed_area[match(ids, baseline$sites$site_id)]
    if (is.null(core$water_share)) core$water_share <- stats::setNames(rep(0, nrow(sites)), sites$site_id)
    core$water_share[ids] <- baseline$sites$water_yard_share[match(ids, baseline$sites$site_id)]
    if (keep_geometry && !is.null(baseline$geometry)) {
      core$geometry <- rbind(core$geometry, baseline$geometry[baseline$geometry$site_id %in% ids, ])
    }
  }
  out <- finish_envelope(core, s_df, res, sig, settings)
  out$report$copied_from_baseline <- length(copied)
  out$report$surfaces_missing <- surf$missing
  out$report$surface_partial <- length(unique(surf$bands$site_id))
  out$scenario <- prep$scenario
  out
}

# ---- Signatures --------------------------------------------------------------

site_signatures <- function(prep, res, settings, bands = NULL) {
  s <- prep$sites
  seg <- sf::st_drop_geometry(prep$segments)
  cols <- intersect(c("boundary_class", "tags", "x0", "y0", "x1", "y1", "outward_bearing",
                      "dist_from_frontage", "adjacent_tokens", "adjacent_area", "ground"), names(seg))
  seg_by <- split(seg[cols], factor(seg$site_id, levels = s$site_id))
  wkb <- wk::as_wkb(sf::st_geometry(s))
  legs <- prep$access_legs
  leg_by <- split(as.numeric(legs$area), factor(legs$site_id, levels = s$site_id))
  dist_by <- split(prep$distances$distance, factor(prep$distances$site_id, levels = s$site_id))
  attrs <- sf::st_drop_geometry(s)[intersect(c("area", "net_area", "is_rear", "is_corner", "road_width",
                                               "slope", "ground_mean", "depth", "width", "frontage"),
                                             names(s))]
  env_settings <- settings[c("level_reference", "min_floorplate", "include_density", "choice",
                             "max_storeys", "defaults", "version", "exclusion_hash", "terrain",
                             "max_ground_slope", "morphology")]
  w_sig <- rlang::hash(prep$water)
  band_by <- if (!is.null(bands) && nrow(bands)) split(paste(bands$upper, round(geos::geos_area(bands$geom), 3)),
                                                      factor(bands$site_id, levels = s$site_id)) else list()
  vapply(seq_len(nrow(s)), function(i) {
    if (is.na(res$param_id[i])) return(NA_character_)
    rlang::hash(list(unclass(wkb[[i]]), seg_by[[i]], attrs[i, ], leg_by[[i]], dist_by[[i]],
                     res$param_id[i], env_settings, w_sig, band_by[[s$site_id[i]]]))
  }, "")
}

# ---- The storey loop -----------------------------------------------------------

envelope_core <- function(prep, res, rb, settings, idx, excl = list(), bands = NULL, keep_geometry,
                          keep_setbacks) {
  sites <- prep$sites
  s_df <- sf::st_drop_geometry(sites)
  empty <- list(stack = empty_stack_df(), variants = data.frame(site_id = character(),
           variant = character(), floor_area = numeric(), stringsAsFactors = FALSE),
           geometry = NULL, setbacks = NULL, report = list())
  params <- res$params
  pid <- res$param_id
  method_of <- vapply(params, function(z) z$method %||% "none", "")
  ok_method <- c("volumetric", "hybrid", if (settings$include_density) "density")
  live <- idx[!is.na(pid[idx]) & method_of[pid[idx]] %in% ok_method]
  if (!length(live)) return(empty)

  # Storey heights and counts per parameter set.
  ph <- lapply(params, storey_plan, rb = rb, dflt = settings$defaults)
  runs <- do.call(rbind, lapply(live, function(i) {
    v <- param_variants(params[[pid[i]]])
    data.frame(site = i, param = pid[i], variant = v, stringsAsFactors = FALSE)
  }))
  runs$n_storeys <- vapply(runs$param, function(p) ph[[p]]$n, 0)
  runs$n_storeys <- pmin(runs$n_storeys, settings$max_storeys)
  nr <- nrow(runs)
  report <- list(no_height = sum(vapply(unique(runs$param), function(p) is.na(ph[[p]]$n), TRUE)))
  runs$n_storeys[is.na(runs$n_storeys)] <- 0

  # Buildable ground: the site, less its access leg and any water yards.
  sg <- as_geos(sites)
  ground <- sg
  if (isTRUE(prep$morphology$exclude_access_legs) && nrow(prep$access_legs)) {
    li <- match(prep$access_legs$site_id, sites$site_id)
    ground[li] <- safe_difference(ground[li], as_geos(prep$access_legs))
  }
  before_water <- geos::geos_area(ground)
  ground <- water_yards(ground, sites, pid, params, prep$water, live)
  water_share <- ifelse(s_df$area > 0, (before_water - geos::geos_area(ground)) / s_df$area, 0)
  # Exclusion overlays: land that comes off the buildable ground ("all"), or
  # where floor area may not be dwellings ("residential").
  removed <- rep(0, nrow(sites))
  res_geom <- NULL
  zone_of <- s_df$zone_key
  for (e in excl) {
    i <- live[is.null(e$zones) | zone_of[live] %in% e$zones]
    if (!length(i)) next
    hit <- i[geos::geos_intersects(ground[i], rep(e$geom, length(i)))]
    if (!length(hit)) next
    if (e$removes == "all") {
      before <- geos::geos_area(ground[hit])
      ground[hit] <- safe_difference(ground[hit], rep(e$geom, length(hit)))
      removed[hit] <- removed[hit] + before - geos::geos_area(ground[hit])
    } else {
      if (is.null(res_geom)) res_geom <- rep(wk::wk_set_crs(geos::as_geos_geometry("POLYGON EMPTY"),
                                                            wk::wk_crs(sg)), nrow(sites))
      res_geom[hit] <- geos::geos_union(res_geom[hit], geos::geos_intersection(sg[hit], rep(e$geom, length(hit))))
    }
  }

  # Segments and which rules apply to each, per run.
  seg <- sf::st_drop_geometry(prep$segments)
  seg_geom <- as_geos(prep$segments)
  seg$site <- match(seg$site_id, sites$site_id)
  segs_by_site <- split(seq_len(nrow(seg)), factor(seg$site, levels = seq_len(nrow(sites))))
  rs_seg <- unlist(segs_by_site[runs$site], use.names = FALSE)
  rs_run <- rep(seq_len(nr), lengths(segs_by_site[runs$site]))
  rs_start <- c(0, cumsum(lengths(segs_by_site[runs$site])))[seq_len(nr)]
  rank_in_site <- stats::ave(seq_len(nrow(seg)), seg$site, FUN = seq_along)

  pairs <- applicable_pairs(runs, rs_run, rs_seg, seg, s_df, params, prep$distances)
  report$unevaluated <- pairs$unevaluated
  pairs <- pairs$pairs

  # Reflex corners of each site's boundary, filled at the larger setback.
  corners <- reflex_corners(seg_geom, seg$site, sg)

  min_fp <- settings$min_floorplate
  gap_cache <- new.env(parent = emptyenv())
  stack <- vector("list", max(runs$n_storeys, 1))
  geoms <- if (keep_geometry) vector("list", length(stack)) else NULL
  sbk <- if (keep_setbacks) vector("list", length(stack)) else NULL
  alive <- runs$n_storeys >= 1
  terrain <- terrain_terms(seg, seg_geom, s_df, sg, settings)

  for (n in seq_len(max(runs$n_storeys, 0))) {
    at <- alive & runs$n_storeys >= n
    if (!any(at)) break
    lv <- storey_levels(ph, runs$param, n)
    level <- if (settings$level_reference == "ceiling") lv$ceiling else lv$floor
    req <- required_setbacks(pairs, rs_seg, rs_run, level, n, seg, s_df, prep$distances, terrain)
    sb <- req$setback
    sb[!at[rs_run]] <- 0
    fp <- clip_runs(ground[runs$site], seg_geom, rs_seg, rs_run, sb, corners, runs, rs_start, rank_in_site)
    # Height surfaces covering part of a site: each storey loses the land the
    # surface is too low for at its level (capacityengine item 368).
    if (!is.null(bands) && nrow(bands)) {
      bi <- match(bands$site_id, sites$site_id)
      for (r in which(at & runs$site %in% bi)) {
        k <- which(bi == runs$site[r] & bands$upper < level[r] - 1e-6)
        if (length(k)) fp[r] <- safe_difference(fp[r], geos::geos_unary_union(geos::geos_make_collection(bands$geom[k])))
      }
    }
    # Building length and separation: gaps of the separation every length
    # along the site's oriented rectangle, at the storeys separation applies.
    fp <- cut_building_gaps(fp, at, runs, params, level, sg, gap_cache)
    fp <- drop_small_parts(fp, min_fp)
    area <- geos::geos_area(fp)
    w <- which(at)
    stack[[n]] <- data.frame(run = w, storey = n, floor_level = lv$floor[w],
                             ceiling_level = lv$ceiling[w], clipped_area = area[w],
                             residential_excluded = if (is.null(res_geom)) 0 else
                               geos::geos_area(geos::geos_intersection(fp[w], res_geom[runs$site[w]])))
    if (keep_geometry) geoms[[n]] <- list(run = w, storey = n, geom = fp[w])
    if (keep_setbacks) {
      k <- which(at[rs_run])
      sbk[[n]] <- data.frame(run = rs_run[k], segment_id = seg$segment_id[rs_seg[k]], storey = n,
                             level = level[rs_run[k]], setback = sb[k], rule = req$rule[k],
                             source = req$source[k], stringsAsFactors = FALSE)
    }
    alive[at] <- area[at] >= min_fp
  }
  st <- do.call(rbind, stack[!vapply(stack, is.null, TRUE)])
  if (is.null(st)) st <- data.frame(run = integer(), storey = integer(), floor_level = numeric(),
                                    ceiling_level = numeric(), clipped_area = numeric(),
                                    residential_excluded = numeric())
  st <- apply_caps(st, runs, s_df, params, settings)
  st <- stack_rules(st, min_fp)
  totals <- tapply(st$enabled_area, factor(st$run, levels = seq_len(nr)), sum)
  totals[is.na(totals)] <- 0
  variants <- data.frame(site_id = s_df$site_id[runs$site], variant = runs$variant,
                         floor_area = as.vector(totals), stringsAsFactors = FALSE)
  chosen <- choose_variant(runs, as.vector(totals), settings$choice)
  keep <- st$run %in% which(chosen)
  st <- st[keep, , drop = FALSE]
  st$site_id <- s_df$site_id[runs$site[st$run]]
  st$variant <- runs$variant[st$run]
  st$param_id <- runs$param[st$run]
  out_stack <- st[, c(names(empty_stack_df()), "residential_excluded")]

  geometry <- NULL
  if (keep_geometry) {
    gl <- geoms[!vapply(geoms, is.null, TRUE)]
    if (length(gl)) {
      g <- do.call(c, lapply(gl, `[[`, "geom"))
      df <- data.frame(run = unlist(lapply(gl, `[[`, "run")), storey = unlist(lapply(gl, `[[`, "storey")))
      ok <- chosen[df$run]
      geometry <- sf::st_sf(site_id = s_df$site_id[runs$site[df$run[ok]]], storey = df$storey[ok],
                            geometry = sf::st_as_sfc(g[ok]))
      sf::st_crs(geometry) <- sf::st_crs(sites)
    }
  }
  setbacks <- NULL
  if (keep_setbacks) {
    sb_all <- do.call(rbind, sbk[!vapply(sbk, is.null, TRUE)])
    if (!is.null(sb_all)) {
      sb_all <- sb_all[chosen[sb_all$run], , drop = FALSE]
      sb_all$site_id <- s_df$site_id[runs$site[sb_all$run]]
      sb_all$run <- NULL
      setbacks <- sb_all
    }
  }
  report$removed_by_exclusions <- sum(removed > 0)
  # A tower's plan dimension and separation limit its shape, not an area; not
  # modelled (as capacityengine), counted where they would apply.
  tdim <- vapply(params, function(z) !is.null(z$form$max_tower_dimension) || !is.null(z$form$tower_separation), TRUE)
  if (any(tdim) && nrow(st)) {
    th <- vapply(params, function(z) z$form$tower_above_height %||% Inf, 0)
    rp <- runs$param[st$run]
    report$tower_controls_unmodelled <- length(unique(st$run[tdim[rp] & st$ceiling_level > th[rp]]))
  }
  list(stack = out_stack, variants = variants, geometry = geometry, setbacks = setbacks, report = report,
       removed = stats::setNames(removed, s_df$site_id),
       water_share = stats::setNames(water_share, s_df$site_id))
}

empty_stack_df <- function() {
  data.frame(site_id = character(), variant = character(), param_id = character(),
             storey = integer(), floor_level = numeric(), ceiling_level = numeric(),
             clipped_area = numeric(), enabled_area = numeric(), binding = character(),
             stringsAsFactors = FALSE)
}

# Storey height, ground floor height and storey count for a parameter set.
storey_plan <- function(z, rb, dflt) {
  h <- z$height
  if (is.null(h)) return(list(n = NA, s = NA, g = NA, occ = NA))
  value <- if (is.numeric(h$value)) h$value else NA_real_
  if (isTRUE(h$no_limit) && is.na(value)) value <- dflt$no_limit_height %||% NA_real_
  occ <- h$occupiable %||% (value - (h$roof_allowance %||% 0))
  if (is.null(occ) || is.na(occ)) return(list(n = NA, s = NA, g = NA, occ = NA))
  s <- h$zone_storey_height %||% storey_height_of(z, dflt$storey_height %||% 3)
  g <- z$ground_floor_height %||% dflt$ground_floor_height %||% s
  n <- if (occ < g - 1e-6) 0 else 1 + floor((occ - g) / s + 1e-6)
  list(n = n, s = s, g = g, occ = occ, total = value)
}

storey_levels <- function(ph, param, n) {
  s <- vapply(param, function(p) ph[[p]]$s, 0)
  g <- vapply(param, function(p) ph[[p]]$g, 0)
  ceiling <- g + (n - 1) * s
  floor <- if (n == 1) rep(0, length(s)) else g + (n - 2) * s
  list(floor = unname(floor), ceiling = unname(ceiling))
}

# Which (run, segment, rule) triples apply, from everything that does not
# depend on height: boundary class or tag, and the rule's conditions.
applicable_pairs <- function(runs, rs_run, rs_seg, seg, s_df, params, distances) {
  rules <- list()
  out <- list()
  unevaluated <- c()
  water_tags <- c("riparian", "coastal", "lakeside")
  grp <- paste(runs$param, runs$variant, sep = "\r")
  for (g in unique(grp)) {
    r_ids <- which(grp == g)
    p <- runs$param[r_ids[1]]
    v <- runs$variant[r_ids[1]]
    z <- params[[p]]
    active <- Filter(function(s) is.null(s$variant) || identical(s$variant, v), z$setbacks %||% list())
    # Water yards are measured from the water, not from a boundary.
    active <- Filter(function(s) !all(s$boundaries %in% water_tags), active)
    if (!length(active)) next
    k <- which(rs_run %in% r_ids)
    sg <- rs_seg[k]
    for (rule in active) {
      ri <- length(rules) + 1
      rules[[ri]] <- rule
      cls <- seg$boundary_class[sg]
      tagm <- vapply(rule$boundaries, function(b) grepl(paste0("|", b, "|"), seg$tags[sg], fixed = TRUE),
                     logical(length(sg)))
      if (!is.matrix(tagm)) tagm <- matrix(tagm, ncol = length(rule$boundaries))
      hit <- cls %in% rule$boundaries | rowSums(tagm) > 0
      cond <- eval_conditions(rule$when, seg[sg, ], s_df[seg$site[sg], ], distances)
      unevaluated <- c(unevaluated, cond$unevaluated[hit & cond$unevaluated != ""])
      ok <- hit & cond$ok
      if (any(ok)) out[[length(out) + 1]] <- data.frame(rs = k[ok], rule = ri)
    }
  }
  pairs <- if (length(out)) do.call(rbind, out) else data.frame(rs = integer(), rule = integer())
  attr(pairs, "rules") <- rules
  list(pairs = pairs, unevaluated = if (length(unevaluated)) table(unevaluated) else NULL)
}

# Evaluate a rule's conditions on segments (with their sites' attributes).
# Returns `ok` and, where a condition could not be evaluated, its name.
eval_conditions <- function(w, sg, st, distances) {
  n <- nrow(sg)
  ok <- rep(TRUE, n)
  unev <- rep("", n)
  if (is.null(w)) return(list(ok = ok, unevaluated = unev))
  pos <- function(test, name) {
    na <- is.na(test)
    unev[na & unev == ""] <<- name
    ok <<- ok & !na & test
  }
  if (!is.null(w$min_site_area)) ok <- ok & st$area >= w$min_site_area
  if (!is.null(w$max_site_area)) ok <- ok & st$area < w$max_site_area
  if (!is.null(w$rear_sites)) ok <- ok & switch(w$rear_sites, include = TRUE, exclude = !st$is_rear, only = st$is_rear)
  if (!is.null(w$corner_sites)) ok <- ok & switch(w$corner_sites, include = TRUE, exclude = !st$is_corner, only = st$is_corner)
  if (!is.null(w$within_frontage)) pos(sg$dist_from_frontage <= w$within_frontage, "within_frontage")
  if (!is.null(w$beyond_frontage)) pos(sg$dist_from_frontage >= w$beyond_frontage, "beyond_frontage")
  if (!is.null(w$frontage_depth_share)) {
    pos(sg$dist_from_frontage >= w$frontage_depth_share * st$depth, "frontage_depth_share")
  }
  if (!is.null(w$adjacent_zones)) {
    tok <- sg$adjacent_tokens
    m <- Reduce(`|`, lapply(w$adjacent_zones, function(z) grepl(paste0("|", z, "|"), tok, fixed = TRUE)))
    m[is.na(tok)] <- NA
    pos(m, "adjacent_zones")
  }
  if (!is.null(w$not_adjacent_zones)) {
    tok <- sg$adjacent_tokens
    m <- Reduce(`|`, lapply(w$not_adjacent_zones, function(z) grepl(paste0("|", z, "|"), tok, fixed = TRUE)))
    # Unknown across: the exemption is not applied, so the rule bites.
    unev[is.na(tok) & unev == ""] <- "not_adjacent_zones"
    ok <- ok & (is.na(tok) | !m)
  }
  if (!is.null(w$facing)) {
    b <- sg$outward_bearing %% 360
    from <- w$facing[1] %% 360
    to <- w$facing[2] %% 360
    pos(if (from <= to) b >= from & b < to else b >= from | b < to, "facing")
  }
  rw <- st$road_width %||% rep(NA_real_, n)
  if (!is.null(w$min_road_width)) pos(rw >= w$min_road_width, "road_width")
  if (!is.null(w$max_road_width)) pos(rw <= w$max_road_width, "road_width")
  sl <- st$slope %||% rep(NA_real_, n)
  if (!is.null(w$min_slope)) pos(sl >= w$min_slope, "slope")
  if (!is.null(w$max_slope)) pos(sl <= w$max_slope, "slope")
  if (!is.null(w$distance_to)) {
    d <- distances$distance[distances$layer == w$distance_to][match(st$site_id, distances$site_id[distances$layer == w$distance_to])]
    t <- rep(TRUE, n)
    if (!is.null(w$min_distance)) t <- t & d >= w$min_distance
    if (!is.null(w$max_distance)) t <- t & d <= w$max_distance
    pos(t, "distance_to")
  }
  list(ok = ok, unevaluated = unev)
}

# Required setback on every (run, segment) at this storey: the largest any
# applicable rule asks, and which rule asked it.
required_setbacks <- function(pairs, rs_seg, rs_run, level, n, seg, s_df, distances, terrain) {
  setback <- numeric(length(rs_seg))
  rule_name <- rep(NA_character_, length(rs_seg))
  source <- rep(NA_character_, length(rs_seg))
  rules <- attr(pairs, "rules")
  if (!nrow(pairs)) return(list(setback = setback, rule = rule_name, source = source))
  d <- numeric(nrow(pairs))
  for (ri in unique(pairs$rule)) {
    k <- which(pairs$rule == ri)
    rule <- rules[[ri]]
    rs <- pairs$rs[k]
    si <- seg$site[rs_seg[rs]]
    bh <- level[rs_run[rs]]
    h <- bh
    sl <- 0
    # Planes and height-proportional rules are measured from the ground at
    # their own boundary (unless the rule says the site's ground).
    if (rule$kind %in% c("plane", "proportional", "profile") && !identical(rule$datum, "site")) {
      h <- h + terrain$offset[rs_seg[rs]]
      if (rule$kind == "plane") sl <- terrain$slope[rs_seg[rs]]
    }
    st <- s_df[si, ]
    vars <- list(site_area = st$area, site_depth = st$depth, site_width = st$width,
                 frontage = st$frontage, n_frontages = st$n_frontage_directions,
                 road_width = st$road_width, slope = st$slope %||% rep(NA_real_, length(k)),
                 corner = as.numeric(st$is_corner), storey = rep(n, length(k)))
    dd <- setback_distance(rule, h, storey = n, bearing = seg$outward_bearing[rs_seg[rs]], vars = vars,
                           slope_in = sl, base_height = bh)
    origin <- rule$origin %||% "boundary"
    if (origin == "road_far_side") dd <- dd - st$road_width
    if (origin == "road_centreline") dd <- dd - st$road_width / 2
    d[k] <- pmax(0, ifelse(is.na(dd), 0, dd))
  }
  o <- order(pairs$rs, -d)
  first <- !duplicated(pairs$rs[o])
  w <- o[first]
  setback[pairs$rs[w]] <- d[w]
  win_rule <- pairs$rule[w]
  rule_name[pairs$rs[w]] <- vapply(rules[win_rule], function(r) r$name %||% r$kind, "")
  source[pairs$rs[w]] <- vapply(rules[win_rule], function(r) r$source %||% NA_character_, "")
  rule_name[setback == 0] <- NA
  source[setback == 0] <- NA
  list(setback = setback, rule = rule_name, source = source)
}

# Clip every run's ground back from its boundaries by the required setbacks,
# in one buffer, one grouped union and one difference.
clip_runs <- function(ground, seg_geom, rs_seg, rs_run, sb, corners, runs, rs_start, rank_in_site) {
  keep <- which(is.finite(sb) & sb > 0)
  if (!length(keep)) return(ground)
  buf <- geos::geos_buffer(seg_geom[rs_seg[keep]], sb[keep],
                           geos::geos_buffer_params(end_cap_style = "flat", quad_segs = 8L))
  ri <- rs_run[keep]
  if (!is.null(corners)) {
    # Corner rows per run of that corner's site.
    by_site <- split(seq_len(nrow(corners)), corners$site)
    cr <- unlist(by_site[as.character(runs$site)], use.names = FALSE)
    if (length(cr)) {
      rr <- rep(seq_len(nrow(runs)), lengths(by_site[as.character(runs$site)]))
      a <- rs_start[rr] + rank_in_site[corners$a[cr]]
      b <- rs_start[rr] + rank_in_site[corners$b[cr]]
      R <- pmax(sb[a], sb[b])
      w <- corner_wedges(corners[cr, ], R)
      if (!is.null(w)) {
        buf <- c(buf, wk::wk_set_crs(w$geom, wk::wk_crs(buf)))
        ri <- c(ri, rr[w$use])
      }
    }
  }
  o <- order(ri)
  ri <- ri[o]
  grp <- unique(ri)
  excl <- geos::geos_unary_union(geos::geos_make_collection(buf[o], feature_id = match(ri, grp)))
  out <- ground
  out[grp] <- safe_difference(ground[grp], excl)
  out
}

safe_difference <- function(a, b) {
  out <- tryCatch(geos::geos_difference(a, b), error = function(e) NULL)
  if (!is.null(out)) return(out)
  out <- a
  for (i in seq_along(a)) {
    out[i] <- tryCatch(geos::geos_difference(a[i], b[i]), error = function(e) {
      tryCatch(geos::geos_difference(geos::geos_set_precision(geos::geos_make_valid(a[i]), 0.001),
                                     geos::geos_set_precision(geos::geos_make_valid(b[i]), 0.001)),
               error = function(e2) geos::geos_difference(geos::geos_make_valid(a[i]),
                                                          geos::geos_buffer(geos::geos_make_valid(b[i]), 0.001)))
    })
  }
  out
}

# Vertices where the boundary bends away from the site. A flat-capped buffer
# leaves a wedge uncovered there, which reads as a tooth reaching to the road;
# it is filled at the larger of the two setbacks that meet (capacityengine
# item 300).
reflex_corners <- function(geom, site_idx, footprints) {
  n <- length(geom)
  if (n < 2) return(NULL)
  s <- geos::geos_point_start(geom)
  e <- geos::geos_point_end(geom)
  sx <- geos::geos_x(s)
  sy <- geos::geos_y(s)
  ex <- geos::geos_x(e)
  ey <- geos::geos_y(e)
  len <- sqrt((ex - sx)^2 + (ey - sy)^2)
  ok <- !is.na(len) & len > 1e-9
  ux <- (ex - sx) / len
  uy <- (ey - sy) / len
  nx <- -uy
  ny <- ux
  inside <- rep(FALSE, n)
  w <- which(ok)
  if (length(w)) {
    probe <- points_like((sx[w] + ex[w]) / 2 + nx[w] * 0.05, (sy[w] + ey[w]) / 2 + ny[w] * 0.05, footprints)
    inside[w] <- geos::geos_intersects(probe, footprints[site_idx[w]])
  }
  nx[!inside] <- -nx[!inside]
  ny[!inside] <- -ny[!inside]
  ends <- data.frame(seg = c(seq_len(n), seq_len(n)), x = c(sx, ex), y = c(sy, ey),
                     dx = c(ux, -ux), dy = c(uy, -uy))[c(ok, ok), , drop = FALSE]
  key <- paste(site_idx[ends$seg], round(ends$x, 2), round(ends$y, 2))
  o <- order(key)
  ends <- ends[o, , drop = FALSE]
  key <- key[o]
  first <- match(key, unique(key))
  cnt <- tabulate(first)[first]
  pair <- which(key[-1] == key[-length(key)] & cnt[-1] == 2)
  if (!length(pair)) return(NULL)
  a <- ends[pair, , drop = FALSE]
  b <- ends[pair + 1L, , drop = FALSE]
  dot <- nx[a$seg] * b$dx + ny[a$seg] * b$dy
  r <- dot < -1e-9 & a$seg != b$seg
  if (!any(r)) return(NULL)
  a <- a[r, , drop = FALSE]
  b <- b[r, , drop = FALSE]
  data.frame(x = a$x, y = a$y, a = a$seg, b = b$seg, ang_a = atan2(ny[a$seg], nx[a$seg]),
             ang_b = atan2(ny[b$seg], nx[b$seg]), site = site_idx[a$seg])
}

corner_wedges <- function(corners, R) {
  use <- which(is.finite(R) & R > 0)
  if (!length(use)) return(NULL)
  cr <- corners[use, , drop = FALSE]
  R <- R[use]
  k <- 8L
  d <- atan2(sin(cr$ang_b - cr$ang_a), cos(cr$ang_b - cr$ang_a))
  # Overlap the strips by a thousandth of a radian each side: abutting edges
  # are coincident and leave zero-width spikes in the difference.
  eps <- 1e-3 * sign(d)
  a0 <- cr$ang_a - eps
  d <- d + 2 * eps
  rc <- R / cos(abs(d) / (2 * k))
  th <- a0 + outer(d, (0:k) / k)
  x <- cbind(cr$x, cr$x + rc * cos(th), cr$x)
  y <- cbind(cr$y, cr$y + rc * sin(th), cr$y)
  m <- ncol(x)
  geom <- geos::geos_make_polygon(as.vector(t(x)), as.vector(t(y)),
                                  feature_id = rep(seq_len(nrow(cr)), each = m))
  list(geom = geom, use = use)
}

# Parts smaller than a floorplate are not a floor; dropping them also removes
# the crumbs a polygon difference leaves on a detailed boundary.
drop_small_parts <- function(g, min_m2) {
  if (!is.finite(min_m2) || min_m2 <= 0 || !length(g)) return(g)
  n <- geos::geos_num_geometries(g)
  n[geos::geos_is_empty(g)] <- 0L
  idx <- rep(seq_along(g), n)
  part <- geos::geos_geometry_n(g[idx], sequence(n))
  a <- geos::geos_area(part)
  keep <- !is.na(a) & a >= min_m2
  out <- g
  gi <- idx[keep]
  lost <- seq_along(g)
  if (length(gi)) {
    grp <- unique(gi)
    out[grp] <- geos::geos_make_collection(part[keep], type_id = 6L, feature_id = match(gi, grp))
    lost <- setdiff(lost, grp)
  }
  if (length(lost)) out[lost] <- wk::wk_set_crs(geos::as_geos_geometry("POLYGON EMPTY"), wk::wk_crs(g))
  out
}

# Water yards: land within each water yard's distance of a river, the coast or
# a lake comes off the buildable ground (measured from the water itself).
water_yards <- function(ground, sites, pid, params, water, live) {
  if (is.null(water) || !nrow(water)) return(ground)
  wg <- as_geos(water)
  wtag <- if ("type" %in% names(water)) water_tag_of(water$type) else rep("riparian", nrow(water))
  for (tg in unique(wtag)) {
    d <- vapply(live, function(i) {
      z <- params[[pid[i]]]
      v <- vapply(z$setbacks %||% list(), function(s) {
        if (identical(s$kind, "yard") && tg %in% s$boundaries && is.numeric(s$distance)) s$distance else 0
      }, 0)
      if (length(v)) max(v) else 0
    }, 0)
    for (dist in setdiff(unique(d), 0)) {
      i <- live[d == dist]
      zone <- geos::geos_unary_union(geos::geos_make_collection(geos::geos_buffer(wg[wtag == tg], dist)))
      hit <- i[geos::geos_intersects(ground[i], zone)]
      if (length(hit)) ground[hit] <- safe_difference(ground[hit], rep(zone, length(hit)))
    }
  }
  ground
}

# Non-spatial caps on each storey: coverage and what landscaping and
# impervious limits leave (shares of NET site area, most restrictive wins),
# maximum floorplate. The clipped polygon is where a building may sit; the cap
# is how much of it may be built.
apply_caps <- function(st, runs, s_df, params, settings) {
  if (!nrow(st)) {
    st$enabled_area <- numeric()
    st$binding <- character()
    return(st)
  }
  si <- runs$site[st$run]
  net <- s_df$net_area[si] %||% s_df$area[si]
  net[is.na(net)] <- s_df$area[si][is.na(net)]
  cov <- land <- imp <- fpl <- twr <- rep(Inf, nrow(st))
  for (p in unique(runs$param[st$run])) {
    k <- which(runs$param[st$run] == p)
    z <- params[[p]]
    vars <- list(site_area = s_df$area[si[k]], height = st$ceiling_level[k],
                 H = st$ceiling_level[k], storey = st$storey[k],
                 site_depth = s_df$depth[si[k]], road_width = s_df$road_width[si[k]],
                 slope = s_df$slope[si[k]] %||% rep(NA_real_, length(k)))
    r <- z$ratios
    if (!is.null(r$coverage_max)) cov[k] <- resolve_ratio(r$coverage_max, vars) * net[k]
    if (!is.null(r$landscaping_min)) land[k] <- (1 - resolve_ratio(r$landscaping_min, vars)) * net[k]
    if (!is.null(r$impervious_max) && identical(settings$ground_mode, "with_access")) {
      imp[k] <- resolve_ratio(r$impervious_max, vars) * net[k]
    }
    if (!is.null(z$form$max_floorplate)) fpl[k] <- z$form$max_floorplate
    # Above the tower threshold, the tower floorplate limit.
    tf <- z$form$max_tower_floorplate
    if (!is.null(tf)) {
      above <- (!is.null(z$form$tower_above_height) & st$ceiling_level[k] > (z$form$tower_above_height %||% Inf)) |
        (!is.null(z$form$tower_above_storey) & st$storey[k] >= (z$form$tower_above_storey %||% Inf))
      twr[k][above] <- tf
    }
  }
  caps <- cbind(geometry = st$clipped_area, coverage = cov, landscaping = land,
                impervious = imp, floorplate = fpl, tower_floorplate = twr)
  caps[is.na(caps)] <- Inf
  b <- max.col(-caps, ties.method = "first")
  st$enabled_area <- caps[cbind(seq_len(nrow(st)), b)]
  st$binding <- colnames(caps)[b]
  st
}

# The stack never widens going up; a storey under the minimum floorplate ends
# the stack.
stack_rules <- function(st, min_fp) {
  if (!nrow(st)) return(st)
  st <- st[order(st$run, st$storey), , drop = FALSE]
  cm <- stats::ave(st$enabled_area, st$run, FUN = cummin)
  narrowed <- cm < st$enabled_area - 1e-9
  st$binding[narrowed] <- "stack_monotonic"
  st$enabled_area <- cm
  dead <- stats::ave(as.numeric(st$enabled_area < min_fp), st$run, FUN = cummax) > 0
  st[!dead, , drop = FALSE]
}

choose_variant <- function(runs, totals, choice) {
  site <- runs$site
  if (choice %in% c("max", "min")) {
    o <- order(site, if (choice == "max") -totals else totals)
    pick <- o[!duplicated(site[o])]
  } else {
    pref <- runs$variant == choice
    o <- order(site, !pref, -totals)
    pick <- o[!duplicated(site[o])]
  }
  out <- rep(FALSE, nrow(runs))
  out[pick] <- TRUE
  out
}

finish_envelope <- function(core, s_df, res, sig, settings) {
  st <- core$stack
  st <- st[order(st$site_id, st$storey), , drop = FALSE]
  rownames(st) <- NULL
  f <- factor(st$site_id, levels = s_df$site_id)
  storeys <- tapply(st$storey, f, max)
  floor_area <- tapply(st$enabled_area, f, sum)
  footprint <- tapply(st$enabled_area[st$storey == 1], factor(st$site_id[st$storey == 1], levels = s_df$site_id), sum)
  top <- tapply(st$ceiling_level, f, max)
  mode_of <- function(x) if (!length(x)) NA_character_ else names(sort(table(x), decreasing = TRUE))[1]
  bind <- tapply(st$binding, f, mode_of)
  var <- tapply(st$variant, f, function(x) x[1])
  sites <- data.frame(site_id = s_df$site_id, zone_key = s_df$zone_key,
                      param_id = res$param_id,
                      variant = as.vector(var), storeys = as.integer(as.vector(storeys)),
                      height = as.vector(top), footprint = as.vector(footprint),
                      floor_area = as.vector(floor_area), binding = as.vector(bind),
                      stringsAsFactors = FALSE)
  sites$storeys[is.na(sites$storeys)] <- 0L
  sites$floor_area[is.na(sites$floor_area)] <- 0
  sites$footprint[is.na(sites$footprint)] <- 0
  sites$flag <- ifelse(is.na(sites$param_id), "no_rules",
                       ifelse(sites$floor_area == 0, "no_envelope", "ok"))
  sites$water_yard_share <- as.vector(core$water_share[s_df$site_id] %||% 0)
  sites$water_yard_share[is.na(sites$water_yard_share)] <- 0
  sites$removed_area <- as.vector(core$removed[s_df$site_id] %||% 0)
  sites$removed_area[is.na(sites$removed_area)] <- 0
  structure(list(stack = st, sites = sites, variants = core$variants, geometry = core$geometry,
                 setbacks = core$setbacks, report = core$report,
                 signatures = stats::setNames(sig, s_df$site_id), settings = settings),
            class = "plancap_envelope")
}

#' @export
print.plancap_envelope <- function(x, ...) {
  s <- x$sites
  cli::cli_text("{.strong <plancap envelope>} {x$scenario %||% ''}: {sum(s$floor_area > 0)} of \\
                 {nrow(s)} sites build; {format(round(sum(s$floor_area)), big.mark = ',')} m2 of floor area.")
  cli::cli_text("{.emph Plan-enabled, gross, blank-slate building envelope (before yield and use split).}")
  b <- sort(table(x$stack$binding), decreasing = TRUE)
  if (length(b)) cli::cli_text("Binding constraint by storey: {paste0(names(b), ' ', round(100 * b / sum(b)), '%', collapse = ', ')}.")
  if (!is.null(x$report$unevaluated)) {
    u <- x$report$unevaluated
    cli::cli_alert_warning("Rules not applied where their condition could not be evaluated: \\
                            {paste(names(u), u, sep = ': ', collapse = '; ')}.")
  }
  if (isTRUE(x$report$copied_from_baseline > 0)) {
    cli::cli_text("{x$report$copied_from_baseline} site{?s} unchanged from the baseline, copied.")
  }
  invisible(x)
}

# Exclusion overlays with their geometry, filtered and buffered, dissolved.
exclusion_layers <- function(rb, layers, crs) {
  out <- list()
  for (id in names(rb$overlays)) {
    d <- rb$overlays[[id]]
    if (!identical(d$type, "exclusion") || isFALSE(d$enabled)) next
    lyr <- layers[[d$layer]]
    if (is.null(lyr) || !inherits(lyr, "sf") || !nrow(lyr)) next
    if (sf::st_crs(lyr) != crs) lyr <- sf::st_transform(lyr, crs)
    for (f in names(d$filter)) lyr <- lyr[as.character(lyr[[f]]) %in% as.character(d$filter[[f]]), ]
    if (!nrow(lyr)) next
    g <- as_geos(lyr)
    if (!is.null(d$buffer)) {
      r <- if (is.numeric(d$buffer)) d$buffer else as.numeric(lyr[[d$buffer]])
      g <- geos::geos_buffer(g, r)
    }
    g <- g[geos::geos_type(g) %in% c("polygon", "multipolygon")]
    if (!length(g)) next
    out[[id]] <- list(geom = geos::geos_unary_union(geos::geos_make_collection(g)),
                      removes = d$removes %||% "all", zones = d$applies_to_zones)
  }
  out
}

# ---- Height surfaces ------------------------------------------------------------

# Sample every enabled height surface (a terra SpatRaster in the scenario's
# layers) over the sites in its zones. A surface covering almost all of a site
# (99%) caps its height at the surface's lowest point above ground; one
# covering less leaves the height alone and instead takes, at each storey, the
# land where the surface is lower than that storey (capacityengine item 368).
sample_surfaces <- function(prep, rb, layers, dflt, covered_min = 0.99) {
  empty <- list(mods = data.frame(site_id = character(), what = character(), value = numeric(),
                                  stringsAsFactors = FALSE), bands = NULL, missing = character())
  defs <- Filter(function(o) identical(o$type, "height_surface") && !isFALSE(o$enabled), rb$overlays)
  if (!length(defs)) return(empty)
  s <- prep$sites
  sd <- sf::st_drop_geometry(s)
  mods <- list()
  bands <- list()
  missing <- character()
  for (id in names(defs)) {
    d <- defs[[id]]
    r <- layers[[d$layer]]
    if (is.null(r) || !inherits(r, "SpatRaster")) {
      missing <- c(missing, d$layer)
      next
    }
    rlang::check_installed("terra", reason = "to sample height surfaces.")
    absolute <- !identical(d$surface_datum, "ground")
    if (absolute && is.null(sd$ground_mean)) {
      missing <- c(missing, paste0(d$layer, " (needs a dem)"))
      next
    }
    sel <- which(!is.na(sd$zone_key) & (is.null(d$applies_to_zones) | sd$zone_key %in% d$applies_to_zones))
    if (!length(sel)) next
    v <- terra::vect(sf::st_transform(s[sel, ], terra::crs(r)))
    lo <- terra::extract(r, v, fun = min, na.rm = TRUE)[, 2]
    n <- terra::extract(r, v, fun = function(x, ...) sum(!is.na(x)))[, 2]
    cell <- prod(terra::res(r))
    cov <- pmin(1, n * cell / sd$area[sel])
    ground <- if (absolute) sd$ground_mean[sel] else 0
    above <- pmax(lo - ground, 0)
    if (!is.null(d$floor_value)) above <- pmax(above, d$floor_value)
    full <- !is.na(above) & cov >= covered_min
    if (any(full)) {
      mods[[length(mods) + 1]] <- data.frame(site_id = sd$site_id[sel][full], what = "surface_cap",
                                             value = above[full], stringsAsFactors = FALSE)
    }
    part <- sel[!is.na(lo) & cov > 0 & cov < covered_min]
    for (i in part) {
      b <- surface_bands(s[i, ], r, if (absolute) sd$ground_mean[i] else 0, d$floor_value)
      if (!is.null(b)) bands[[length(bands) + 1]] <- b
    }
  }
  bands <- if (length(bands)) do.call(rbind, bands) else NULL
  if (!is.null(bands)) {
    g <- bands$geom
    bands <- data.frame(site_id = bands$site_id, upper = bands$upper)
    bands$geom <- g
  }
  list(mods = if (length(mods)) do.call(rbind, mods) else empty$mods, bands = bands,
       missing = unique(missing))
}

# The parts of one site under a surface, by the height the surface allows
# there, as polygons: each comes off every storey whose level reaches it.
surface_bands <- function(site, r, ground, floor_value) {
  v <- terra::vect(sf::st_transform(site, terra::crs(r)))
  rc <- tryCatch(terra::crop(r, terra::ext(v) + 2 * max(terra::res(r)), snap = "out"), error = function(e) NULL)
  if (is.null(rc)) return(NULL)
  above <- terra::clamp(rc - ground, lower = floor_value %||% 0, values = TRUE)
  # Bands of 0.5 m: fine enough for any storey height, coarse enough to stay
  # few polygons.
  q <- floor(above * 2) / 2
  pv <- terra::as.polygons(q, dissolve = TRUE)
  if (!nrow(pv)) return(NULL)
  b <- sf::st_as_sf(pv)
  names(b)[1] <- "upper"
  b <- suppressWarnings(sf::st_intersection(sf::st_make_valid(sf::st_transform(b, sf::st_crs(site))),
                                            sf::st_geometry(site)))
  b <- b[!sf::st_is_empty(b), ]
  b <- b[sf::st_dimension(b) %in% 2, ]
  b <- b[as.numeric(sf::st_area(b)) > 0.01, ]
  if (!nrow(b)) return(NULL)
  data.frame(site_id = site$site_id, upper = b$upper) |>
    (\(d) { d$geom <- as_geos(b); d })()
}

# ---- Building length and separation ----------------------------------------------

cut_building_gaps <- function(fp, at, runs, params, level, site_geom, cache) {
  for (p in unique(runs$param[at])) {
    f <- params[[p]]$form
    len <- f$max_building_length
    sep_rule <- f$building_separation
    if (is.null(len) || is.null(sep_rule)) next
    r <- which(at & runs$param == p)
    sep <- if (is.numeric(sep_rule)) rep(sep_rule, length(r)) else
      resolve_ratio(sep_rule, list(height = level[r]))
    for (k in seq_along(r)) {
      if (is.na(sep[k]) || sep[k] <= 0) next
      key <- paste(runs$site[r[k]], len, sep[k])
      g <- cache[[key]]
      if (is.null(g)) {
        g <- building_gaps(site_geom[runs$site[r[k]]], len, sep[k])
        cache[[key]] <- g
      }
      if (!geos::geos_is_empty(g)) fp[r[k]] <- safe_difference(fp[r[k]], g)
    }
  }
  fp
}

# On the site's minimum rotated rectangle, strips `gap` wide every `len` metres
# from one corner, in both directions: a building may run `len`, then stands
# `gap` from the next (capacityengine item 372).
building_gaps <- function(geom, len, gap) {
  crs <- wk::wk_crs(geom)
  rr <- geos::geos_minimum_rotated_rectangle(geom)
  xy <- wk::wk_coords(rr)
  if (nrow(xy) < 4) return(geos::as_geos_geometry("POLYGON EMPTY", crs = crs))
  p0 <- c(xy$x[1], xy$y[1])
  p1 <- c(xy$x[2], xy$y[2])
  p2 <- c(xy$x[3], xy$y[3])
  A <- sqrt(sum((p1 - p0)^2))
  B <- sqrt(sum((p2 - p1)^2))
  if (A < 1e-6 || B < 1e-6) return(geos::as_geos_geometry("POLYGON EMPTY", crs = crs))
  eu <- (p1 - p0) / A
  ev <- (p2 - p1) / B
  rect <- function(o, e1, a, b, e2, w) {
    m <- rbind(o + e1 * a, o + e1 * b, o + e1 * b + e2 * w, o + e1 * a + e2 * w, o + e1 * a)
    sprintf("POLYGON ((%s))", paste(sprintf("%.3f %.3f", m[, 1], m[, 2]), collapse = ", "))
  }
  strips <- character()
  for (dir in 1:2) {
    L <- if (dir == 1) A else B
    W <- if (dir == 1) B else A
    e1 <- if (dir == 1) eu else ev
    e2 <- if (dir == 1) ev else eu
    s0 <- len
    while (s0 < L - 1e-6) {
      strips <- c(strips, rect(p0, e1, s0, min(s0 + gap, L), e2, W))
      s0 <- s0 + gap + len
    }
  }
  if (!length(strips)) return(geos::as_geos_geometry("POLYGON EMPTY", crs = crs))
  geos::geos_unary_union(geos::geos_make_collection(geos::as_geos_geometry(strips, crs = crs)))
}

# ---- Terrain -------------------------------------------------------------------

# Height in relation to a boundary is measured from the ground at that
# boundary; the building's levels are counted from the site's ground. A
# boundary is the plan's unit, not the cadastre's piece of it, so its ground is
# the length-weighted mean over each run of near-straight pieces of one class
# (capacityengine items 297, 299). "flat" stands the building on one floor at
# the site's mean ground; "stepped" (item 318) on a plane fitted to the site's
# boundary ground, so the offset is the plane's height at the run's middle less
# the run's ground, and the plane's rise into the site slows the building's
# gain on a recession plane.
terrain_terms <- function(seg, seg_geom, s_df, site_geom, settings) {
  n <- nrow(seg)
  zero <- list(offset = rep(0, n), slope = rep(0, n))
  if (!"ground" %in% names(seg) || !"ground_mean" %in% names(s_df) || !n) return(zero)
  merge <- settings$morphology$boundary_merge_angle %||% 5
  run <- boundary_runs(seg_geom, seg$site, seg$boundary_class, merge)
  len <- geos::geos_length(seg_geom)
  has <- !is.na(seg$ground)
  num <- rowsum(ifelse(has, seg$ground * len, 0), run)
  den <- rowsum(ifelse(has, len, 0), run)
  k <- match(run, as.integer(rownames(num)))
  rg <- ifelse(den[k] > 0, num[k] / den[k], NA_real_)
  tg <- s_df$ground_mean[seg$site]
  offset <- ifelse(is.na(rg) | is.na(tg), 0, tg - rg)
  slope <- rep(0, n)
  if (identical(settings$terrain, "stepped")) {
    pf <- ground_planes(seg_geom, seg$site, seg$ground, site_geom, settings$max_ground_slope %||% 0.5)
    b <- seg$outward_bearing * pi / 180
    inx <- -sin(b)
    iny <- -cos(b)
    gx <- pf$gx[seg$site]
    gy <- pf$gy[seg$site]
    s <- gx * inx + gy * iny
    s[is.na(s)] <- 0
    wsum <- function(v) {
      r <- rowsum(len * v, run)
      r[match(run, as.integer(rownames(r))), 1]
    }
    W <- wsum(rep(1, n))
    W[W <= 0] <- NA
    rmx <- wsum(pf$mx) / W
    rmy <- wsum(pf$my) / W
    slope <- wsum(s) / W
    slope[is.na(slope)] <- 0
    pb <- pf$z[seg$site] + gx * (rmx - pf$cx[seg$site]) + gy * (rmy - pf$cy[seg$site])
    ok <- !is.na(pb) & !is.na(rg)
    offset[ok] <- pb[ok] - rg[ok]
  }
  list(offset = offset, slope = slope)
}

# Runs of near-straight pieces of one boundary: consecutive segments of one
# site meeting at a turn of no more than `tol_deg`, of the same class.
boundary_runs <- function(geom, site_idx, cls, tol_deg) {
  n <- length(geom)
  run <- seq_len(n)
  if (n < 2 || is.na(tol_deg) || tol_deg <= 0) return(run)
  s <- geos::geos_point_start(geom)
  e <- geos::geos_point_end(geom)
  sx <- geos::geos_x(s)
  sy <- geos::geos_y(s)
  ex <- geos::geos_x(e)
  ey <- geos::geos_y(e)
  len <- sqrt((ex - sx)^2 + (ey - sy)^2)
  ok <- !is.na(len) & len > 1e-9
  ux <- (ex - sx) / len
  uy <- (ey - sy) / len
  ends <- data.frame(seg = c(seq_len(n), seq_len(n)), x = c(sx, ex), y = c(sy, ey),
                     dx = c(ux, -ux), dy = c(uy, -uy))[c(ok, ok), , drop = FALSE]
  key <- paste(site_idx[ends$seg], round(ends$x, 2), round(ends$y, 2))
  o <- order(key)
  ends <- ends[o, , drop = FALSE]
  key <- key[o]
  cnt <- tabulate(match(key, unique(key)))[match(key, unique(key))]
  pair <- which(key[-1] == key[-length(key)] & cnt[-1] == 2)
  if (!length(pair)) return(run)
  a <- ends[pair, ]
  b <- ends[pair + 1L, ]
  turn <- acos(pmin(1, pmax(-1, -(a$dx * b$dx + a$dy * b$dy)))) * 180 / pi
  same <- (is.na(cls[a$seg]) & is.na(cls[b$seg])) |
    (!is.na(cls[a$seg]) & !is.na(cls[b$seg]) & cls[a$seg] == cls[b$seg])
  join <- turn <= tol_deg & same & a$seg != b$seg
  i <- a$seg[join]
  j <- b$seg[join]
  if (!length(i)) return(run)
  repeat {
    m <- pmin(run[i], run[j])
    idx <- c(i, j)
    val <- c(m, m)
    oo <- order(idx, val)
    first <- oo[!duplicated(idx[oo])]
    nxt <- run
    nxt[idx[first]] <- pmin(run[idx[first]], val[first])
    if (identical(nxt, run)) break
    run <- nxt
  }
  run
}

# Each site's ground as a plane z = a + gx (x - cx) + gy (y - cy) about its
# centroid, fitted to its boundaries' ground weighted by length; the slope is
# capped at `max_slope`, and a site whose boundaries do not span it in both
# directions keeps a level plane at their mean.
ground_planes <- function(geom, site_idx, z, site_geom, max_slope = 0.5) {
  ns <- length(site_geom)
  cen <- geos::geos_centroid(site_geom)
  cx <- geos::geos_x(cen)
  cy <- geos::geos_y(cen)
  mid <- geos::geos_interpolate_normalized(geom, 0.5)
  mx <- geos::geos_x(mid)
  my <- geos::geos_y(mid)
  w <- geos::geos_length(geom)
  ok <- !is.na(z) & is.finite(z) & w > 0
  out <- list(cx = cx, cy = cy, z = rep(NA_real_, ns), gx = rep(0, ns), gy = rep(0, ns), mx = mx, my = my)
  if (!any(ok)) return(out)
  i <- site_idx[ok]
  w <- w[ok]
  zz <- z[ok]
  dx <- mx[ok] - cx[i]
  dy <- my[ok] - cy[i]
  S <- function(v) {
    r <- rep(0, ns)
    s <- rowsum(v, i)
    r[as.integer(rownames(s))] <- s[, 1]
    r
  }
  s0 <- S(w); sx <- S(w * dx); sy <- S(w * dy)
  sxx <- S(w * dx * dx); sxy <- S(w * dx * dy); syy <- S(w * dy * dy)
  sz <- S(w * zz); sxz <- S(w * dx * zz); syz <- S(w * dy * zz)
  det <- s0 * (sxx * syy - sxy^2) - sx * (sx * syy - sxy * sy) + sy * (sx * sxy - sxx * sy)
  has <- s0 > 0
  out$z[has] <- sz[has] / s0[has]
  spread <- ifelse(has, (sxx + syy) / pmax(s0, 1e-9), 0)
  good <- has & abs(det) > 1e-6 * s0^3 * pmax(spread, 1e-9)^2
  a <- (sz * (sxx * syy - sxy^2) - sx * (sxz * syy - sxy * syz) + sy * (sxz * sxy - sxx * syz)) / det
  b <- (s0 * (sxz * syy - sxy * syz) - sz * (sx * syy - sxy * sy) + sy * (sx * syz - sxz * sy)) / det
  c <- (s0 * (sxx * syz - sxy * sxz) - sx * (sx * syz - sxz * sy) + sz * (sx * sxy - sxx * sy)) / det
  out$z[good] <- a[good]
  out$gx[good] <- b[good]
  out$gy[good] <- c[good]
  mag <- sqrt(out$gx^2 + out$gy^2)
  over <- mag > max_slope
  if (any(over)) {
    out$gx[over] <- out$gx[over] * max_slope / mag[over]
    out$gy[over] <- out$gy[over] * max_slope / mag[over]
  }
  out
}
