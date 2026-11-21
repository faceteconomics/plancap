#' Identify what each boundary and site is
#'
#' Before any rule can apply, every boundary has to be identified as a road
#' frontage, side or rear boundary, and every site as a corner, through or rear
#' site, with or without an access leg. These helpers do that, each returning
#' the classification **and the evidence** for it, so a wrong call can be
#' traced. All of them follow the same assumptions, from
#' [morphology_defaults()], a rulebook's `morphology` block and the `morphology`
#' argument, in that order of increasing precedence.
#'
#' - `find_road_frontages()`: boundary segments that run along a road parcel.
#' - `find_side_rear()`: the other boundaries, as side or rear, from their
#'   angle to the frontage and how far back they sit.
#' - `find_corner_sites()`, `find_through_sites()`, `find_rear_sites()`: site
#'   types, from the directions the frontages face and the frontage length.
#' - `find_access_legs()`: the narrow strip by which a rear site reaches the
#'   road (a driveway or "battle-axe handle").
#' - `find_water_boundaries()`: boundaries near a river, the coast or a lake.
#' - `find_road_widths()`: width of the road in front of each site.
#' - `site_metrics()`: area, frontage, depth, width and compactness.
#'
#' Boundaries get one **class**, `road`, `side` or `rear`, and any number of
#' **tags** (`riparian`, `coastal`, `lakeside`, `reserve`, `zone_boundary`).
#' A setback rule naming a tag in its `boundaries` applies to boundaries with
#' that tag, so a river boundary stays a side or rear boundary for every other
#' rule.
#'
#' @param sites An `sf` polygon layer of sites (or parcels) in a projected CRS,
#'   with a `site_id` column (created if missing).
#' @param roads Road parcels (polygons), or `NULL`. Without them no boundary is
#'   a road frontage.
#' @param water Water features (lines or polygons), optionally with a `type`
#'   column (`"river"`, `"stream"`, `"coast"`, `"lake"`).
#' @param centrelines Optional road centrelines with a road reserve width
#'   column, see `width_field`.
#' @param width_field Column of `centrelines` holding the road width (m).
#' @param rulebook Optional rulebook whose `morphology` settings apply.
#' @param morphology Named list overriding individual settings for this run.
#' @return `find_road_frontages()`, `find_side_rear()` and
#'   `find_water_boundaries()` return an `sf` table of boundary segments;
#'   `find_access_legs()` an `sf` table of access legs; the others a data frame
#'   with one row per site.
#' @name morphology
#' @examples
#' town <- exampleton()
#' land <- town$parcels[town$parcels$parcel_type == "land", ][1:60, ]
#' roads <- town$parcels[town$parcels$parcel_type == "road", ]
#' head(find_rear_sites(land, roads))
#' legs <- find_access_legs(land, roads)
#' nrow(legs)
NULL

#' @rdname morphology
#' @export
find_road_frontages <- function(sites, roads, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = FALSE, widths = FALSE)
  out <- pg$segments[, c("site_id", "segment_id", "boundary_class", "length",
                         "road_shared_length", "outward_bearing", "geometry")]
  out[out$boundary_class == "road", ]
}

#' @rdname morphology
#' @export
find_side_rear <- function(sites, roads, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = FALSE, widths = FALSE)
  pg$segments[, c("site_id", "segment_id", "boundary_class", "tags", "length", "angle_to_frontage",
                  "dist_from_frontage", "outward_bearing", "geometry")]
}

#' @rdname morphology
#' @export
find_corner_sites <- function(sites, roads, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = FALSE, widths = FALSE)
  sf::st_drop_geometry(pg$sites)[, c("site_id", "frontage", "n_frontage_directions",
                                     "is_corner", "frontage_directions")]
}

#' @rdname morphology
#' @export
find_through_sites <- function(sites, roads, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = FALSE, widths = FALSE)
  sf::st_drop_geometry(pg$sites)[, c("site_id", "frontage", "n_frontage_directions",
                                     "is_through", "frontage_directions")]
}

#' @rdname morphology
#' @export
find_rear_sites <- function(sites, roads, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = TRUE, widths = FALSE)
  sf::st_drop_geometry(pg$sites)[, c("site_id", "frontage", "is_rear", "access_leg_area")]
}

#' @rdname morphology
#' @export
find_access_legs <- function(sites, roads, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = TRUE, widths = FALSE)
  pg$access_legs
}

#' @rdname morphology
#' @export
find_water_boundaries <- function(sites, water, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, water = water, rulebook = rulebook, morphology = morphology,
                        legs = FALSE, widths = FALSE)
  out <- pg$segments[, c("site_id", "segment_id", "boundary_class", "tags", "water_distance",
                         "geometry")]
  out[!is.na(out$water_distance), ]
}

#' @rdname morphology
#' @export
find_road_widths <- function(sites, roads, centrelines = NULL, width_field = "width_m",
                             rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, centrelines = centrelines,
                        width_field = width_field, rulebook = rulebook,
                        morphology = morphology, legs = FALSE, widths = TRUE)
  sf::st_drop_geometry(pg$sites)[, c("site_id", "frontage", "road_width", "road_width_method")]
}

#' @rdname morphology
#' @export
site_metrics <- function(sites, roads = NULL, rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, rulebook = rulebook, morphology = morphology,
                        legs = FALSE, widths = FALSE)
  sf::st_drop_geometry(pg$sites)[, c("site_id", "area", "perimeter", "frontage", "depth",
                                     "width", "compactness")]
}

# ---- Settings -----------------------------------------------------------------

morphology_settings <- function(rulebook = NULL, overrides = list(), call = rlang::caller_env()) {
  m <- morphology_defaults()
  if (!is.null(rulebook)) m <- merge_lists(m, rulebook$morphology %||% list())
  bad <- setdiff(names(overrides), names(m))
  if (length(bad)) cli::cli_abort("Unknown morphology setting{?s}: {.field {bad}}.", call = call)
  merge_lists(m, overrides)
}

# ---- The parcel geometry step --------------------------------------------------

# Everything about sites that depends only on their geometry and the roads,
# water and centrelines: no zoning, no rules. One vectorised pass.
parcel_geometry <- function(sites, roads = NULL, water = NULL, centrelines = NULL,
                            width_field = "width_m", rulebook = NULL, morphology = list(),
                            legs = TRUE, widths = TRUE, easements = NULL, other_parcels = NULL) {
  check_projected(sites)
  if (!"site_id" %in% names(sites)) sites$site_id <- sprintf("S%06d", seq_len(nrow(sites)))
  if (anyDuplicated(sites$site_id)) cli::cli_abort("{.field site_id} values must be unique.")
  m <- morphology_settings(rulebook, morphology)
  sites <- sf::st_make_valid(sites)
  sg <- as_geos(sites)
  ids <- as.character(sites$site_id)
  n_sites <- length(ids)

  seg <- explode_segments(sg, ids)
  si <- match(seg$site_id, ids)
  seg$length <- geos::geos_length(seg$geom)
  ob <- outward_bearing(seg, sg, si)
  seg$outward_bearing <- ob$bearing
  seg$bearing_u <- (atan2(seg$y1 - seg$y0, seg$x1 - seg$x0) * 180 / pi) %% 180
  seg$tags <- "|"

  # Road frontage: a segment that runs along a road parcel for at least half
  # its length (within a small tolerance for cadastral slivers).
  rg <- if (!is.null(roads) && nrow(roads)) as_geos(roads) else NULL
  seg$road_shared_length <- if (is.null(rg)) 0 else shared_length(seg$geom, rg, m$road_tolerance)
  is_road <- seg$length > 0 & seg$road_shared_length / seg$length >= 0.5
  frontage <- as.vector(rowsum(ifelse(is_road, seg$length, 0), factor(si, levels = seq_len(n_sites))))
  # A site whose total road contact is below the minimum does not front a road.
  is_road[frontage[si] < m$min_road_contact] <- FALSE
  frontage[frontage < m$min_road_contact] <- 0
  seg$boundary_class <- ifelse(is_road, "road", NA_character_)

  seg <- side_rear(seg, si, n_sites, m)

  # Frontage directions: cluster road segments by outward bearing.
  dirs <- frontage_directions(seg, si, n_sites, m)

  out <- sites[, "site_id"]
  if ("parcel_ids" %in% names(sites)) out$parcel_ids <- sites$parcel_ids
  if ("landholding" %in% names(sites)) out$landholding <- sites$landholding
  out$area <- geos::geos_area(sg)
  out$perimeter <- geos::geos_length(geos::geos_boundary(sg))
  out$frontage <- frontage
  out$n_frontage_directions <- dirs$n
  out$frontage_directions <- dirs$label
  out$is_corner <- dirs$corner
  out$is_through <- dirs$through
  out$is_rear <- frontage < m$rear_site_max_frontage
  depth_by_site <- tapply(seg$dist_from_frontage, factor(si, levels = seq_len(n_sites)),
                          function(v) if (all(is.na(v))) NA_real_ else max(v, na.rm = TRUE))
  out$depth <- as.vector(depth_by_site)
  out$width <- ifelse(!is.na(out$depth) & out$depth > 0, out$area / out$depth, NA_real_)
  out$compactness <- 4 * pi * out$area / out$perimeter^2
  out$flag <- ifelse(frontage == 0, "no_road_frontage", "ok")
  # Where the plan says a rear site's yards are all rear yards.
  if (isTRUE(m$rear_site_sides_as_rear)) {
    to_rear <- seg$boundary_class %in% "side" & out$is_rear[si]
    seg$boundary_class[to_rear] <- "rear"
    seg$tags[to_rear] <- paste0(seg$tags[to_rear], "rear_site_side|")
  }

  # Access width: frontage, or a rear site's measured access.
  to_g <- function(x) {
    if (is.null(x) || !nrow(x)) return(NULL)
    if (sf::st_crs(x) != sf::st_crs(sites)) x <- sf::st_transform(x, sf::st_crs(sites))
    as_geos(x)
  }
  acc <- measure_access(sg, frontage, rg, to_g(easements), to_g(other_parcels), m)
  out$access_contact <- acc$contact
  out$easement_width <- acc$easement
  out$access_lot_width <- acc$lot
  out$access_width <- acc$width
  out$access_method <- acc$method

  # Access legs of rear sites.
  out$access_leg_area <- 0
  leg_sf <- NULL
  if (legs) {
    lg <- access_legs(sg, seg$geom, si, seg$boundary_class,
                      candidates = out$is_rear & frontage > 0,
                      max_width = m$access_leg_max_width,
                      min_contact = m$access_leg_min_road_contact)
    if (!is.null(lg)) {
      out$access_leg_area[lg$site_idx] <- lg$area
      leg_sf <- sf::st_sf(site_id = ids[lg$site_idx], area = lg$area,
                          geometry = sf::st_as_sfc(lg$geom))
      sf::st_crs(leg_sf) <- sf::st_crs(sites)
    }
  }
  if (is.null(leg_sf)) {
    leg_sf <- sf::st_sf(site_id = character(), area = numeric(),
                        geometry = sf::st_sfc(crs = sf::st_crs(sites)))
  }
  out$net_area <- out$area - if (isTRUE(m$exclude_access_legs)) out$access_leg_area else 0

  # Water: tag boundaries within the set distance of a water feature.
  seg$water_distance <- NA_real_
  if (!is.null(water) && nrow(water)) {
    seg <- tag_water(seg, water, m$water_boundary_distance)
  }

  # Road width in front of each site.
  out$road_width <- NA_real_
  out$road_width_method <- NA_character_
  if (widths && any(frontage > 0)) {
    rw <- road_widths(seg, si, n_sites, rg, centrelines, width_field, ob)
    out$road_width <- rw$width
    out$road_width_method <- rw$method
  }

  seg_sf <- seg[, c("site_id", "segment_id", "boundary_class", "tags", "length",
                    "outward_bearing", "angle_to_frontage", "dist_from_frontage",
                    "road_shared_length", "water_distance", "x0", "y0", "x1", "y1")]
  seg_sf$geometry <- sf::st_as_sfc(seg$geom)
  seg_sf <- sf::st_as_sf(seg_sf)
  sf::st_crs(seg_sf) <- sf::st_crs(sites)
  list(sites = out, segments = seg_sf, access_legs = leg_sf, morphology = m)
}

# Side versus rear, as capacityengine: a segment is rear when it is within the
# angle tolerance of parallel to the frontage axis AND sits at least
# `rear_depth_share` of the way back from the frontage; everything else is side.
side_rear <- function(seg, si, n_sites, m) {
  is_road <- !is.na(seg$boundary_class) & seg$boundary_class == "road"
  th <- seg$bearing_u * pi / 180
  w <- ifelse(is_road, seg$length, 0)
  f <- factor(si, levels = seq_len(n_sites))
  sin_sum <- as.vector(rowsum(w * sin(2 * th), f))
  cos_sum <- as.vector(rowsum(w * cos(2 * th), f))
  has_front <- as.vector(rowsum(as.numeric(is_road), f)) > 0
  axis <- rep(NA_real_, n_sites)
  axis[has_front] <- (atan2(sin_sum[has_front], cos_sum[has_front]) / 2) %% pi * 180 / pi

  seg$dist_from_frontage <- NA_real_
  road_idx <- which(is_road)
  if (length(road_idx)) {
    front_sites <- sort(unique(si[road_idx]))
    ord <- order(si[road_idx])
    fronts <- geos::geos_unary_union(geos::geos_make_collection(
      seg$geom[road_idx][ord], feature_id = match(si[road_idx][ord], front_sites)))
    sf_i <- match(si, front_sites)
    live <- !is.na(sf_i)
    mid <- geos::geos_interpolate(seg$geom[live], seg$length[live] / 2)
    seg$dist_from_frontage[live] <- geos::geos_distance(mid, fronts[sf_i[live]])
  }
  d <- abs(seg$bearing_u - axis[si]) %% 180
  seg$angle_to_frontage <- pmin(d, 180 - d)
  depth <- ifelse(is.na(seg$dist_from_frontage), -Inf, seg$dist_from_frontage)
  acc <- rep(-Inf, n_sites)
  o <- order(depth)
  acc[si[o]] <- depth[o]
  max_depth <- acc[si]
  max_depth[!is.finite(max_depth)] <- NA_real_
  is_rear <- is.na(seg$boundary_class) & !is.na(seg$angle_to_frontage) &
    seg$angle_to_frontage <= m$side_rear_angle_tolerance &
    !is.na(seg$dist_from_frontage) & !is.na(max_depth) & max_depth > 0 &
    seg$dist_from_frontage >= m$rear_depth_share * max_depth
  seg$boundary_class[is_rear] <- "rear"
  seg$boundary_class[is.na(seg$boundary_class)] <- "side"
  seg
}

# Group each site's road segments into frontage directions by their outward
# bearing (a full circle: a through site's two frontages face opposite ways).
# Directions are separated by gaps wider than the corner tolerance, and a
# direction counts only if its frontage is at least `corner_min_frontage`.
frontage_directions <- function(seg, si, n_sites, m) {
  n <- integer(n_sites)
  corner <- through <- logical(n_sites)
  label <- rep(NA_character_, n_sites)
  r <- which(seg$boundary_class == "road")
  if (!length(r)) return(list(n = n, corner = corner, through = through, label = label))
  by_site <- split(r, si[r])
  for (s in names(by_site)) {
    k <- by_site[[s]]
    b <- seg$outward_bearing[k]
    len <- seg$length[k]
    o <- order(b)
    b <- b[o]
    len <- len[o]
    gaps <- c(diff(b), b[1] + 360 - b[length(b)])
    breaks <- which(gaps > m$corner_angle_tolerance)
    if (length(breaks) <= 1) {
      cl_bear <- circ_mean(b, len)
      cl_len <- sum(len)
    } else {
      # Clusters run from just after one wide gap to the next.
      start <- (breaks %% length(b)) + 1
      grp <- integer(length(b))
      for (j in seq_along(start)) {
        idx <- start[j]
        repeat {
          grp[idx] <- j
          if (idx %in% breaks) break
          idx <- idx %% length(b) + 1
        }
      }
      cl_bear <- vapply(seq_along(start), function(j) circ_mean(b[grp == j], len[grp == j]), 0)
      cl_len <- vapply(seq_along(start), function(j) sum(len[grp == j]), 0)
    }
    keep <- cl_len >= m$corner_min_frontage
    cl_bear <- cl_bear[keep]
    i <- as.integer(s)
    n[i] <- length(cl_bear)
    if (length(cl_bear)) label[i] <- paste(round(cl_bear), collapse = ",")
    if (length(cl_bear) > 1) {
      pairs <- utils::combn(length(cl_bear), 2)
      dd <- bearing_diff(cl_bear[pairs[1, ]], cl_bear[pairs[2, ]])
      through[i] <- any(dd >= m$through_min_bearing_difference)
      corner[i] <- any(dd > m$corner_angle_tolerance & dd < m$through_min_bearing_difference)
    }
  }
  list(n = n, corner = corner, through = through, label = label)
}

circ_mean <- function(b, w = rep(1, length(b))) {
  th <- b * pi / 180
  (atan2(sum(w * sin(th)), sum(w * cos(th))) * 180 / pi) %% 360
}

# Access legs, as capacityengine's access_legs(): open the site with a buffer
# in and out at half the leg width; what the opening removes is narrow land,
# and a narrow part that touches the road is the leg.
access_legs <- function(site_geom, seg_geom, seg_site_idx, seg_class, candidates,
                        max_width = 7.5, min_contact = 0.5) {
  road <- which(!is.na(seg_class) & seg_class == "road")
  rear <- which(candidates)
  if (!length(road) || !length(rear) || max_width <= 0) return(NULL)
  g <- geos::geos_make_valid(site_geom[rear])
  bp <- geos::geos_buffer_params(join_style = "mitre", mitre_limit = 5)
  core <- geos::geos_make_valid(geos::geos_buffer(
    geos::geos_buffer(g, -max_width / 2, params = bp), max_width / 2, params = bp))
  has_body <- !geos::geos_is_empty(core) & geos::geos_area(core) > 0
  if (!any(has_body)) return(NULL)
  rear <- rear[has_body]
  g <- g[has_body]
  narrow <- geos::geos_difference(g, core[has_body])
  k <- geos::geos_num_geometries(narrow)
  k[geos::geos_is_empty(narrow)] <- 0L
  if (!sum(k)) return(NULL)
  owner <- rep(seq_along(narrow), k)
  parts <- geos::geos_geometry_n(narrow[owner], sequence(k))
  rr <- road[seg_site_idx[road] %in% rear]
  if (!length(rr)) return(NULL)
  rid <- match(seg_site_idx[rr], rear)
  ord <- order(rid)
  grp <- unique(rid[ord])
  roads <- rep(geos::as_geos_geometry("LINESTRING EMPTY"), length(rear))
  roads <- wk::wk_set_crs(roads, wk::wk_crs(site_geom))
  roads[grp] <- geos::geos_make_collection(seg_geom[rr][ord], feature_id = match(rid[ord], grp))
  contact <- geos::geos_length(geos::geos_intersection(parts, roads[owner]))
  leg <- contact >= min_contact
  if (!any(leg)) return(NULL)
  lo <- owner[leg]
  ul <- unique(lo)
  geom <- geos::geos_unary_union(geos::geos_make_collection(
    parts[leg][order(lo)], feature_id = match(lo[order(lo)], ul)))
  list(site_idx = rear[ul], area = geos::geos_area(geom), geom = geom)
}

water_tag_of <- function(type) {
  t <- tolower(as.character(type))
  ifelse(grepl("coast|sea|ocean|harbour|marine", t), "coastal",
         ifelse(grepl("lake|pond|reservoir", t), "lakeside", "riparian"))
}

tag_water <- function(seg, water, max_distance) {
  wg <- as_geos(water)
  tag <- if ("type" %in% names(water)) water_tag_of(water$type) else rep("riparian", nrow(water))
  cand <- geos::geos_intersects_matrix(seg$geom, geos::geos_buffer(wg, max_distance))
  n <- lengths(cand)
  if (!sum(n)) return(seg)
  s <- rep(seq_along(cand), n)
  f <- unlist(cand, use.names = FALSE)
  d <- geos::geos_distance(seg$geom[s], wg[f])
  o <- order(s, d)
  first <- !duplicated(s[o])
  hit_s <- s[o][first]
  hit_f <- f[o][first]
  seg$water_distance[hit_s] <- d[o][first]
  seg$tags[hit_s] <- paste0(seg$tags[hit_s], tag[hit_f], "|")
  seg
}

# Width of the road in front of each site, at the middle of its longest road
# segment: from a centreline's width attribute where given, otherwise measured
# by stepping across the road parcels until leaving them.
road_widths <- function(seg, si, n_sites, rg, centrelines, width_field, ob,
                        step = 0.5, max_width = 80) {
  width <- rep(NA_real_, n_sites)
  method <- rep(NA_character_, n_sites)
  r <- which(seg$boundary_class == "road")
  o <- order(si[r], -seg$length[r])
  pick <- r[o][!duplicated(si[r][o])]
  sites_i <- si[pick]
  mx <- ob$mx[pick]
  my <- ob$my[pick]
  ox <- ob$ox[pick]
  oy <- ob$oy[pick]
  if (!is.null(centrelines) && width_field %in% names(centrelines)) {
    cg <- as_geos(centrelines)
    pt <- points_like(mx + ox * 2, my + oy * 2, cg)
    near <- geos::geos_nearest(pt, cg)
    d <- geos::geos_distance(pt, cg[near])
    ok <- !is.na(near) & d <= max_width
    width[sites_i[ok]] <- as.numeric(centrelines[[width_field]][near[ok]])
    method[sites_i[ok]] <- "centreline"
  }
  todo <- which(is.na(width[sites_i]))
  if (length(todo) && !is.null(rg)) {
    found <- rep(NA_real_, length(pick))
    open <- todo
    for (d in seq(step / 2, max_width, by = step)) {
      if (!length(open)) break
      pt <- points_like(mx[open] + ox[open] * d, my[open] + oy[open] * d, rg)
      inside <- lengths(geos::geos_intersects_matrix(pt, rg)) > 0
      found[open[!inside]] <- d - step / 2
      open <- open[inside]
    }
    ok <- !is.na(found)
    width[sites_i[ok]] <- found[ok]
    method[sites_i[ok]] <- "measured"
  }
  list(width = width, method = method)
}
