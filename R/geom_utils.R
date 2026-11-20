# Geometry helpers shared by site preparation. Internal.
#
# Rules carried over from capacityengine, each learned by a slow or wrong run:
# * never loop over sites with GEOS calls inside; group with feature ids,
#   rowsum() and STRtree joins (geos_intersects_matrix());
# * "touching is not overlapping": adjacent cadastral polygons always touch,
#   so tests use shared length or area fractions, never intersects();
# * constructed geometry carries no CRS unless set (points_like());
# * geos_unary_union() is vectorised; to dissolve, collect first.

check_projected <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  crs <- sf::st_crs(x)
  if (is.na(crs)) cli::cli_abort("{.arg {arg}} has no coordinate reference system.", call = call)
  if (isTRUE(sf::st_is_longlat(x))) {
    cli::cli_abort(c("{.arg {arg}} is in a geographic CRS (degrees).",
                     "i" = "Transform it to a projected CRS in metres, e.g. {.code sf::st_transform(x, 2193)}."),
                   call = call)
  }
  invisible(x)
}

as_geos <- function(x) geos::as_geos_geometry(sf::st_geometry(x))

points_like <- function(x, y, like) {
  wk::wk_set_crs(geos::geos_make_point(x, y), wk::wk_crs(like))
}

# First candidate index per element of a list from geos_intersects_matrix().
first_match <- function(cand) {
  n <- lengths(cand)
  flat <- unlist(cand, use.names = FALSE)
  starts <- utils::head(c(0L, cumsum(n)), -1L) + 1L
  out <- flat[starts]
  out[n == 0L] <- NA_integer_
  as.integer(out)
}

# Connected components over n items given lists of linked ids (union-find).
components <- function(n, links) {
  parent <- seq_len(n)
  find <- function(i) {
    root <- i
    while (parent[root] != root) root <- parent[root]
    while (parent[i] != root) {
      nxt <- parent[i]
      parent[i] <<- root
      i <- nxt
    }
    root
  }
  for (i in seq_along(links)) {
    for (j in links[[i]]) {
      a <- find(i)
      b <- find(j)
      if (a != b) parent[b] <- a
    }
  }
  roots <- vapply(seq_len(n), find, numeric(1))
  match(roots, unique(roots))
}

# Explode polygon rings into two-point segments in one vectorised pass.
explode_segments <- function(geom, ids) {
  co <- wk::wk_coords(geom)
  ring_key <- paste(co$feature_id, co$part_id, co$ring_id, sep = ":")
  same_ring <- ring_key[-nrow(co)] == ring_key[-1]
  i0 <- which(same_ring)
  x0 <- co$x[i0]
  y0 <- co$y[i0]
  x1 <- co$x[i0 + 1]
  y1 <- co$y[i0 + 1]
  keep <- (x0 != x1) | (y0 != y1)
  i0 <- i0[keep]
  x0 <- x0[keep]
  y0 <- y0[keep]
  x1 <- x1[keep]
  y1 <- y1[keep]
  feature <- co$feature_id[i0]
  # Ring winding (shoelace, grouped by ring) is a fallback for which side of a
  # segment is inside; a hole is any ring that is not the first of its part.
  ring_of_seg <- ring_key[i0]
  ring_f <- factor(ring_of_seg)
  area2 <- rowsum(x0 * y1 - x1 * y0, ring_f, reorder = FALSE)
  ring_ccw <- as.vector(area2)[match(ring_of_seg, levels(ring_f))] > 0
  first_ring <- co$ring_id[match(co$part_id, co$part_id)]
  ring_is_hole <- co$ring_id[i0] != first_ring[i0]
  n <- length(i0)
  g <- geos::geos_make_linestring(as.numeric(rbind(x0, x1)), as.numeric(rbind(y0, y1)),
                                  feature_id = rep(seq_len(n), each = 2L),
                                  crs = wk::wk_crs(geom))
  data.frame(site_id = ids[feature],
             segment_id = paste0(ids[feature], "-", sequence(rle(feature)$lengths)),
             x0 = x0, y0 = y0, x1 = x1, y1 = y1, ring_ccw = ring_ccw,
             ring_is_hole = ring_is_hole, stringsAsFactors = FALSE) |>
    (\(d) { d$geom <- g; d })()
}

# Which way is out: probe a short distance either side of each segment's
# midpoint and ask the site polygon. Cadastral rings are not consistently
# wound, so (-dy, dx) is not reliably the inward normal. Ring winding settles
# what the probe cannot (a segment on a very thin part).
outward_bearing <- function(seg, site_geom, site_idx, d0 = 0.25, retries = 4L) {
  dx <- seg$x1 - seg$x0
  dy <- seg$y1 - seg$y0
  L <- sqrt(dx * dx + dy * dy)
  nx <- -dy / L
  ny <- dx / L
  mx <- (seg$x0 + seg$x1) / 2
  my <- (seg$y0 + seg$y1) / 2
  sign <- rep(NA_real_, nrow(seg))
  todo <- which(!is.na(site_idx) & L > 0)
  d <- d0
  for (k in 0:retries) {
    if (!length(todo)) break
    a <- points_like(mx[todo] + nx[todo] * d, my[todo] + ny[todo] * d, site_geom)
    b <- points_like(mx[todo] - nx[todo] * d, my[todo] - ny[todo] * d, site_geom)
    in_a <- geos::geos_contains(site_geom[site_idx[todo]], a)
    in_b <- geos::geos_contains(site_geom[site_idx[todo]], b)
    s <- ifelse(in_a & !in_b, -1, ifelse(!in_a & in_b, 1, NA_real_))
    sign[todo] <- s
    todo <- todo[is.na(s)]
    d <- d / 2
  }
  if (length(todo)) {
    # For a counter-clockwise exterior ring the interior is on the left, i.e.
    # on the side of (nx, ny), so the sign is -1 (outward is -(nx, ny)); a
    # hole or a clockwise ring flips it (capacityengine winding_side()).
    sign[todo] <- ifelse(seg$ring_ccw[todo], 1, -1) * ifelse(seg$ring_is_hole[todo], 1, -1)
  }
  ox <- sign * nx
  oy <- sign * ny
  list(bearing = (90 - atan2(oy, ox) * 180 / pi) %% 360, ox = ox, oy = oy,
       mx = mx, my = my)
}

# Circular difference between bearings in degrees (0-180).
bearing_diff <- function(a, b) {
  d <- abs(a - b) %% 360
  pmin(d, 360 - d)
}

# Shared length between each segment and a layer, per segment: the test for
# "runs along", which mere intersection is not.
shared_length <- function(seg_geom, layer_geom, tolerance) {
  if (!length(layer_geom)) return(numeric(length(seg_geom)))
  target <- if (tolerance > 0) geos::geos_buffer(layer_geom, tolerance) else layer_geom
  cand <- geos::geos_intersects_matrix(seg_geom, target)
  out <- numeric(length(seg_geom))
  n_cand <- lengths(cand)
  if (!any(n_cand)) return(out)
  si <- rep(seq_along(cand), n_cand)
  ti <- unlist(cand, use.names = FALSE)
  len <- geos::geos_length(geos::geos_intersection(seg_geom[si], target[ti]))
  agg <- rowsum(len, si, reorder = FALSE)
  out[as.integer(rownames(agg))] <- as.vector(agg)
  pmin(out, geos::geos_length(seg_geom))
}

# Area of overlap between each site and each feature of a polygon layer, as a
# long table. STRtree candidates, then exact intersection areas.
overlap_table <- function(site_geom, feat_geom, min_area = 0.01) {
  cand <- geos::geos_intersects_matrix(site_geom, feat_geom)
  n <- lengths(cand)
  if (!sum(n)) return(data.frame(site = integer(), feature = integer(), area = numeric()))
  si <- rep(seq_along(cand), n)
  fi <- unlist(cand, use.names = FALSE)
  a <- geos::geos_area(geos::geos_intersection(site_geom[si], feat_geom[fi]))
  keep <- a >= min_area
  data.frame(site = si[keep], feature = fi[keep], area = a[keep])
}
