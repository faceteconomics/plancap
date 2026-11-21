#' The existing front setback of the dwellings along a street
#'
#' Some plans set a front yard by what is already there rather than by a
#' number: the Auckland Unitary Plan's Special Character Areas set it as "the
#' average of existing setbacks of dwellings on adjacent sites, being the
#' three sites on either side of the subject site or six sites on one side"
#' (D18.6.1.3.1). A yard declared `yard(value_from = "existing_front_setback")`
#' takes its depth from this measurement, per road boundary.
#'
#' For each road boundary of a site:
#' 1. **The street** is the named street line nearest the boundary's middle,
#'    merged along its length (every line sharing its name), and its
#'    **corridor** is the road parcels that line runs through.
#' 2. **The adjacent sites** are the parcels with at least
#'    `rear_site_max_frontage` of boundary on that corridor, on the same side
#'    of the street, ordered by where each meets it: `front_setback_neighbours`
#'    on each side, or twice that on one side where the other has fewer (a
#'    street end or a corner). A rear site or a sliver is not beside the
#'    subject along the street and is not counted.
#' 3. **A dwelling's setback** is the distance to the corridor of the
#'    front-most building on the parcel with at least
#'    `front_setback_min_dwelling_area` of it inside the parcel, so a garage or
#'    shed is not taken for a dwelling. A neighbour with none adds nothing and
#'    is not replaced, because the plan names which sites.
#' 4. **The yard** is the mean of the setbacks found; `NA` where none is.
#'
#' A corner site gets a yard on each street from that street's neighbours.
#' Building outlines traced from imagery include verandas and porches where
#' the trace does, which a plan's "setback of dwellings" may not settle.
#' This follows capacityengine (items 314, 317 and 325).
#'
#' @param sites Sites, `sf` polygons with a `site_id` column.
#' @param roads Road parcels.
#' @param buildings Building outlines (polygons).
#' @param streets Street centre lines with a name column (`street_field`).
#' @param street_field Column of `streets` holding the street name.
#' @param neighbours Optional further parcels that may be neighbours (outside
#'   the sites studied, so a site at the edge sees across it).
#' @param site_ids Sites to measure. Default all.
#' @param rulebook,morphology Morphology settings, as for [morphology].
#' @return A data frame, one row per road boundary segment measured:
#'   `segment_id`, `site_id`, `street`, `setback` (`NA` where nothing was
#'   measured), `n` (dwellings averaged) and `neighbours` (their ids and
#'   setbacks, as `"id:metres"` joined by `";"`).
#' @export
find_existing_front_setbacks <- function(sites, roads, buildings, streets, street_field = "name",
                                         neighbours = NULL, site_ids = NULL, rulebook = NULL,
                                         morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = FALSE, widths = FALSE)
  seg <- pg$segments
  want <- seg$boundary_class %in% "road" & (is.null(site_ids) | seg$site_id %in% site_ids)
  pool <- neighbour_pool(sites, neighbours)
  existing_front_core(seg[want, ], seg$site_id[want], pool, buildings, roads, streets, street_field,
                      pg$morphology)
}

# Parcels that may be neighbours: the sites, and any further parcels not
# already inside one.
neighbour_pool <- function(sites, extra = NULL) {
  sg <- as_geos(sites)
  ids <- as.character(sites$site_id)
  if (!is.null(extra) && nrow(extra)) {
    if (sf::st_crs(extra) != sf::st_crs(sites)) extra <- sf::st_transform(extra, sf::st_crs(sites))
    eg <- geos::geos_make_valid(as_geos(extra))
    pos <- geos::geos_point_on_surface(eg)
    hit <- geos::geos_strtree_query(geos::geos_strtree(sg), pos)
    inside <- vapply(seq_along(pos), function(i) {
      k <- hit[[i]]
      length(k) > 0L && any(geos::geos_intersects(sg[k], pos[i]))
    }, logical(1))
    sg <- c(sg, eg[!inside])
    ids <- c(ids, paste0("other_", which(!inside)))
  }
  list(geom = sg, id = ids)
}

# The measurement on road segments `seg` (sf), whose subjects are `subject`
# (ids in the pool).
existing_front_core <- function(seg, subject, pool, buildings, roads, streets, street_field, m) {
  empty <- data.frame(segment_id = character(0), site_id = character(0), street = character(0),
                      setback = numeric(0), n = integer(0), neighbours = character(0),
                      stringsAsFactors = FALSE)
  if (!nrow(seg) || is.null(streets) || !nrow(streets) || is.null(roads) || !nrow(roads)) return(empty)
  if (!street_field %in% names(streets)) {
    cli::cli_abort("The streets layer has no {.field {street_field}} column.")
  }
  crs <- sf::st_crs(seg)
  to_crs <- function(x) if (sf::st_crs(x) == crs) x else sf::st_transform(x, crs)
  streets <- to_crs(streets)
  roads <- to_crs(roads)
  n_side <- as.integer(m$front_setback_neighbours)
  min_front <- m$rear_site_max_frontage
  max_off <- m$front_setback_max_offset

  sg <- as_geos(seg)
  mid <- geos::geos_interpolate_normalized(sg, 0.5)
  st_g <- as_geos(streets)
  st_name <- as.character(streets[[street_field]])
  near <- sf::st_nearest_feature(sf::st_as_sfc(mid), sf::st_as_sfc(st_g))
  name <- st_name[near]
  pg <- pool$geom
  pid <- pool$id
  rg <- as_geos(roads)
  ptree <- geos::geos_strtree(pg)

  # Each parcel's dwellings: buildings with at least the minimum area inside
  # the parcel, clipped to it.
  parts <- geos::geos_empty()
  owner <- integer(0)
  if (!is.null(buildings) && nrow(buildings)) {
    bg <- geos::geos_make_valid(as_geos(to_crs(buildings)))
    hit <- geos::geos_intersects_matrix(pg, bg)
    ii <- rep(seq_along(hit), lengths(hit))
    if (length(ii)) {
      cut <- geos::geos_intersection(bg[unlist(hit)], pg[ii])
      big <- geos::geos_area(cut) >= m$front_setback_min_dwelling_area
      parts <- cut[big]
      owner <- ii[big]
    }
  }
  pos <- function(idx, L, corridor) {
    np <- frontage_point(pg[idx], corridor)
    t <- geos::geos_project(L, np)
    a <- geos::geos_interpolate(L, pmax(t - 1, 0))
    b <- geos::geos_interpolate(L, pmin(t + 1, geos::geos_length(L)))
    c0 <- geos::geos_centroid(pg[idx])
    side <- sign((geos::geos_x(b) - geos::geos_x(a)) * (geos::geos_y(c0) - geos::geos_y(a)) -
                 (geos::geos_y(b) - geos::geos_y(a)) * (geos::geos_x(c0) - geos::geos_x(a)))
    list(t = t, side = side, off = geos::geos_distance(np, L))
  }

  out <- list()
  for (nm in unique(name[!is.na(name)])) {
    here <- which(name == nm)
    line <- geos::geos_line_merge(geos::geos_unary_union(geos::geos_make_collection(st_g[st_name %in% nm])))
    lines <- geos::geos_geometry_n(line, seq_len(geos::geos_num_geometries(line)))
    corridor <- geos::geos_unary_union(geos::geos_make_collection(rg[geos::geos_intersects(rg, line)]))
    if (geos::geos_is_empty(corridor)) next
    near_i <- unique(unlist(geos::geos_strtree_query(ptree, geos::geos_buffer(corridor, 1))))
    touching <- near_i[geos::geos_distance(pg[near_i], corridor) < 0.5]
    front_len <- geos::geos_length(geos::geos_intersection(geos::geos_boundary(pg[touching]),
                                                           geos::geos_buffer(corridor, 0.5)))
    fronting <- touching[front_len >= min_front]
    setback <- rep(NA_real_, length(pg))
    k <- which(owner %in% fronting)
    if (length(k)) {
      dk <- geos::geos_distance(parts[k], corridor)
      mm <- tapply(dk, owner[k], min)
      setback[as.integer(names(mm))] <- as.numeric(mm)
    }
    on_line <- list()
    for (site in unique(subject[here])) {
      own <- which(pid == site)
      if (!length(own)) next
      segs_here <- here[subject[here] == site]
      li <- which.min(geos::geos_distance(lines, mid[[segs_here[[1]]]]))
      L <- lines[[li]]
      key <- as.character(li)
      if (is.null(on_line[[key]])) on_line[[key]] <- pos(fronting, L, corridor)
      p <- on_line[[key]]
      at <- match(own[[1]], fronting)
      me <- if (!is.na(at)) list(t = p$t[[at]], side = p$side[[at]]) else pos(own[[1]], L, corridor)
      ok <- !(fronting %in% own) & p$side == me$side & p$off <= max_off
      cand <- fronting[ok]
      tt <- p$t[ok]
      before <- cand[tt < me$t][order(-tt[tt < me$t])]
      after <- cand[tt >= me$t][order(tt[tt >= me$t])]
      nb <- min(length(before), n_side)
      na <- min(length(after), n_side)
      if (nb < n_side) na <- min(length(after), 2L * n_side - nb)
      if (na < n_side) nb <- min(length(before), 2L * n_side - na)
      pick <- c(before[seq_len(nb)], after[seq_len(na)])
      d <- setback[pick]
      used <- !is.na(d)
      out[[length(out) + 1L]] <- data.frame(
        segment_id = seg$segment_id[segs_here], site_id = seg$site_id[segs_here], street = nm,
        setback = if (any(used)) mean(d[used]) else NA_real_, n = sum(used),
        neighbours = paste(sprintf("%s:%s", pid[pick], ifelse(used, sprintf("%.1f", d), "none")),
                           collapse = ";"),
        stringsAsFactors = FALSE)
    }
  }
  if (!length(out)) return(empty)
  do.call(rbind, out)
}

# Where each parcel meets a corridor: the middle of its boundary within half a
# metre of it, or its centroid where it does not meet it.
frontage_point <- function(parcels, corridor) {
  edge <- geos::geos_intersection(geos::geos_boundary(parcels), geos::geos_buffer(corridor, 0.5))
  pt <- geos::geos_centroid(edge)
  miss <- geos::geos_is_empty(edge)
  if (any(miss)) pt[miss] <- geos::geos_centroid(parcels[miss])
  pt
}

# Sites whose rules carry a yard set from the neighbours' setbacks.
needs_front_measure <- function(res) {
  need_p <- vapply(res$params, function(z) {
    any(vapply(z$setbacks %||% list(), function(s) identical(s$kind, "yard") && !is.null(s$value_from), TRUE))
  }, TRUE)
  !is.na(res$param_id) & need_p[res$param_id] %in% TRUE
}

# The measured front yard on every road segment of the sites that need it,
# for build_envelopes(); cached on its inputs.
measure_front_yards <- function(x, prep, res) {
  need <- needs_front_measure(res)
  if (!any(need)) return(NULL)
  streets <- x$streets %||% x$centrelines
  if (is.null(x$buildings) || is.null(streets) || is.null(x$roads)) {
    return(list(values = NULL, missing_inputs = TRUE, sites = sum(need)))
  }
  seg <- prep$segments
  s_df <- sf::st_drop_geometry(prep$sites)
  ids <- s_df$site_id[need]
  want <- seg$boundary_class %in% "road" & seg$site_id %in% ids
  # Subjects are found in the pool by their parcel (a zone-split piece by its
  # parent).
  subject <- s_df$parent_id[match(seg$site_id[want], s_df$site_id)]
  key <- rlang::hash(list("front", prep$hashes[["parcel_geometry"]], seg$segment_id[want], x$buildings,
                          streets, x$street_field, x$neighbours %||% x$other_parcels, prep$morphology))
  m <- cache_get(key)
  if (is.null(m)) {
    sites <- make_sites(x$parcels, x$site_id, x$group_by)
    pool <- neighbour_pool(sites, x$neighbours %||% x$other_parcels)
    m <- existing_front_core(seg[want, ], subject, pool, x$buildings, x$roads, streets,
                             x$street_field %||% "name", prep$morphology)
    cache_set(key, m)
  }
  list(values = m, missing_inputs = FALSE, sites = sum(need))
}
