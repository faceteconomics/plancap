#' The site shape factor: can a site hold the plan's rectangle?
#'
#' Some plans require every vacant site created by subdivision to hold a
#' rectangle of a stated size clear of its yards (Auckland Unitary Plan
#' E38.8.1.1(2): 8 m by 15 m, 15 m by 20 m in the Terrace Housing and Apartment
#' Buildings zone). A zone states its rectangle as `form$site_shape`
#' (`width`, `depth`; see [building_form()]).
#'
#' The rule governs creating vacant sites, so it bears on the subdivision
#' paths only (density, large site, and a hybrid zone taking its density
#' count); [estimate_capacity()] applies it there. A site that cannot hold one
#' rectangle creates no new site and keeps one dwelling; none creates more
#' sites than its developable area holds rectangles (a necessary bound, not a
#' packing).
#'
#' **The developable area** is the site less the zone's yards (each a
#' flat-ended strip along the boundaries it applies to), less water yards and
#' the land exclusion overlays take off.
#'
#' **The test, at any orientation**, cheapest first:
#' 1. it *fails* if the area is under width x depth, if its minimum rotated
#'    rectangle is narrower than the width or shorter than the depth, or if it
#'    cannot hold a disc as wide as the rectangle;
#' 2. it *passes* if the rectangle fits laid along the minimum rotated
#'    rectangle's axes, at its centre or at a point well inside the area;
#' 3. otherwise it is decided *exactly to a grid*: the area is rasterised at
#'    `cell` in a frame turned to each of its own edge directions and every
#'    `angle_step` degrees, and a summed-area table asks whether any window of
#'    the rectangle's size, either way round, lies wholly inside.
#'
#' This is stage 1 of capacityengine's design (item 324): a building
#' complying with every zone standard is not also required to fit within the
#' rectangle, and exclusions for which no layer is supplied (hazards,
#' heritage, utilities) are not seen, so the result is optimistic.
#'
#' @param x A [scenario()].
#' @param site_ids Sites to test. Default: sites in density zones with a
#'   rectangle that are at least twice the zone's vacant site minimum (smaller
#'   sites count one dwelling whatever their shape).
#' @param angle_step Sweep step of the exact test, degrees.
#' @param cell Raster cell of the exact test, metres.
#' @return A data frame, one row per site tested: `site_id`, `rect_width`,
#'   `rect_depth`, `developable_area`, `fits`, `max_lots` and `decided_by`
#'   (`"area"`, `"rotated_rectangle"`, `"inscribed_disc"`, `"aligned"` or
#'   `"raster"`).
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning)
#' head(site_shape_factor(sc))
site_shape_factor <- function(x, site_ids = NULL, angle_step = 5, cell = 0.25) {
  if (!inherits(x, "plancap_scenario")) cli::cli_abort("{.arg x} must be a {.fn scenario}.")
  rb <- x$rulebook
  prep <- prepare_sites(x)
  res <- resolve_sites(prep, rb)
  excl <- exclusion_layers(rb, x$layers, sf::st_crs(prep$sites))
  shape_factor_core(prep, res, excl, site_ids = site_ids, angle_step = angle_step, cell = cell)
}

shape_factor_core <- function(prep, res, excl = list(), site_ids = NULL, angle_step = 5, cell = 0.25) {
  sites <- prep$sites
  s_df <- sf::st_drop_geometry(sites)
  params <- res$params
  pid <- res$param_id
  pz <- lapply(pid, function(p) if (is.na(p)) NULL else params[[p]])
  rect_w <- vapply(pz, function(z) z$form$site_shape$width %||% NA_real_, 0)
  rect_d <- vapply(pz, function(z) z$form$site_shape$depth %||% NA_real_, 0)
  if (is.null(site_ids)) {
    method <- vapply(pz, function(z) z$method %||% NA_character_, "")
    mins <- vapply(pz, function(z) z$density$vacant_site_min_area %||% z$density$min_site_area %||% NA_real_, 0)
    keep <- method %in% "density" & !is.na(mins) & s_df$area >= 2 * mins
  } else {
    keep <- s_df$site_id %in% site_ids
  }
  keep <- which(keep & !is.na(rect_w) & !is.na(rect_d))
  n <- length(keep)
  out <- data.frame(site_id = s_df$site_id[keep], rect_width = rect_w[keep], rect_depth = rect_d[keep],
                    developable_area = rep(NA_real_, n), fits = rep(NA, n),
                    max_lots = rep(NA_integer_, n), decided_by = rep(NA_character_, n),
                    stringsAsFactors = FALSE)
  if (!n) return(out)

  # The developable area: the site less its yards, water yards and exclusions.
  sg <- as_geos(sites)
  dev <- sg
  dev <- water_yards(dev, sites, pid, params, prep$water, keep)
  zone_of <- s_df$zone_key
  for (e in excl) {
    if (!identical(e$removes, "all")) next
    i <- keep[is.null(e$zones) | zone_of[keep] %in% e$zones]
    if (!length(i)) next
    hit <- i[geos::geos_intersects(dev[i], rep(e$geom, length(i)))]
    if (length(hit)) dev[hit] <- safe_difference(dev[hit], rep(e$geom, length(hit)))
  }
  seg <- sf::st_drop_geometry(prep$segments)
  seg_geom <- as_geos(prep$segments)
  si <- match(seg$site_id, s_df$site_id)
  use <- which(si %in% keep)
  if (length(use)) {
    # The yards of the vacant sites being created, by the boundaries' own
    # classes (a rear site's sides are sides of the new sites).
    cls <- ground_class(seg)
    depth <- vapply(use, function(k) shape_yard_depth(pz[[si[k]]], cls[k], seg$tags[k]), 0)
    use <- use[depth > 0]
    depth <- depth[depth > 0]
    if (length(use)) {
      strip <- geos::geos_buffer(seg_geom[use], depth, params = geos::geos_buffer_params(end_cap_style = "flat"))
      by_site <- split(seq_along(use), si[use])
      for (s in names(by_site)) {
        i <- as.integer(s)
        cut <- geos::geos_unary_union(geos::geos_make_collection(strip[by_site[[s]]]))
        dev[i] <- safe_difference(dev[i], cut)
      }
    }
  }
  dev <- dev[keep]
  A <- rect_d[keep]
  B <- rect_w[keep]
  area <- geos::geos_area(dev)
  out$developable_area <- area
  out$max_lots <- as.integer(floor(area / (A * B) + 1e-9))

  fits <- rep(NA, n)
  how <- rep(NA_character_, n)
  small <- area < A * B
  fits[small] <- FALSE
  how[small] <- "area"
  mrr <- geos::geos_minimum_rotated_rectangle(dev)
  dims <- t(vapply(seq_along(mrr), function(i) {
    xy <- wk::wk_coords(mrr[i])
    if (nrow(xy) < 4) return(c(0, 0, 0, 0, 0))
    e1 <- c(xy$x[2] - xy$x[1], xy$y[2] - xy$y[1])
    e2 <- c(xy$x[3] - xy$x[2], xy$y[3] - xy$y[2])
    l1 <- sqrt(sum(e1^2))
    l2 <- sqrt(sum(e2^2))
    ang <- if (l1 >= l2) atan2(e1[2], e1[1]) else atan2(e2[2], e2[1])
    c(max(l1, l2), min(l1, l2), ang, mean(xy$x[1:4]), mean(xy$y[1:4]))
  }, numeric(5)))
  narrow <- is.na(fits) & (dims[, 1] < A | dims[, 2] < B)
  fits[narrow] <- FALSE
  how[narrow] <- "rotated_rectangle"
  inner <- geos::geos_buffer(dev, -B / 2)
  nodisc <- is.na(fits) & (geos::geos_is_empty(inner) | geos::geos_area(inner) <= 0)
  fits[nodisc] <- FALSE
  how[nodisc] <- "inscribed_disc"

  und <- which(is.na(fits))
  if (length(und)) {
    pin <- geos::geos_point_on_surface(inner[und])
    try_at <- function(cx, cy, ang) {
      r <- rect_polygons(cx, cy, A[und], B[und], ang, wk::wk_crs(dev))
      geos::geos_contains(dev[und], r)
    }
    ok <- try_at(dims[und, 4], dims[und, 5], dims[und, 3]) |
      try_at(geos::geos_x(pin), geos::geos_y(pin), dims[und, 3])
    ok[is.na(ok)] <- FALSE
    fits[und[ok]] <- TRUE
    how[und[ok]] <- "aligned"
  }
  for (i in which(is.na(fits))) {
    fits[i] <- rect_fits_grid(dev[i], A[i], B[i], angle_step, cell)
    how[i] <- "raster"
  }
  out$fits <- fits
  out$decided_by <- how
  out
}

# The deepest yard a zone puts on a boundary of this class or tag, at ground
# level; conditions are not evaluated (as capacityengine's stage 1).
shape_yard_depth <- function(z, cls, tags) {
  v <- vapply(z$setbacks %||% list(), function(s) {
    if (!identical(s$kind, "yard")) return(0)
    b <- unlist(s$boundaries)
    # Water yards are measured from the water (taken off above), not from a
    # boundary, as in the envelope.
    b <- setdiff(b, c("riparian", "coastal", "lakeside"))
    if (!length(b)) return(0)
    on <- cls %in% b || any(vapply(b, function(t) grepl(paste0("|", t, "|"), tags %||% "|", fixed = TRUE), TRUE))
    if (!on || !is.null(s$from_storey) || !is.null(s$above_height)) return(0)
    d <- tryCatch(setback_distance(s, 0), error = function(e) NA_real_)
    if (is.na(d)) 0 else d
  }, 0)
  if (length(v)) max(v) else 0
}

# Rectangles of a x b centred at (cx, cy), the long side at angle ang.
rect_polygons <- function(cx, cy, a, b, ang, crs) {
  ca <- cos(ang)
  sa <- sin(ang)
  hx <- a / 2
  hy <- b / 2
  wkt <- vapply(seq_along(cx), function(i) {
    cr <- function(sx, sy) c(cx[i] + sx * hx[i] * ca[i] - sy * hy[i] * sa[i],
                              cy[i] + sx * hx[i] * sa[i] + sy * hy[i] * ca[i])
    m <- rbind(cr(-1, -1), cr(1, -1), cr(1, 1), cr(-1, 1), cr(-1, -1))
    paste0("POLYGON ((", paste(sprintf("%.6f %.6f", m[, 1], m[, 2]), collapse = ", "), "))")
  }, "")
  wk::wk_set_crs(geos::as_geos_geometry(wkt), crs)
}

# Does an a x b rectangle fit in a polygon at some angle, to a grid of `cell`.
rect_fits_grid <- function(poly, a, b, angle_step = 5, cell = 0.25) {
  xy <- wk::wk_coords(poly)
  if (!nrow(xy)) return(FALSE)
  rings <- split(xy[, c("x", "y")], interaction(xy$feature_id, xy$part_id, xy$ring_id, drop = TRUE))
  cx <- mean(xy$x)
  cy <- mean(xy$y)
  ang <- unlist(lapply(rings, function(r) atan2(diff(r$y), diff(r$x))))
  ang <- unique(round(c(ang %% pi, seq(0, pi - 1e-9, by = angle_step * pi / 180)), 4))
  na <- ceiling(a / cell)
  nb <- ceiling(b / cell)
  for (t in ang) {
    ct <- cos(-t)
    st <- sin(-t)
    rr <- lapply(rings, function(r) {
      x <- r$x - cx
      y <- r$y - cy
      cbind(x * ct - y * st, x * st + y * ct)
    })
    allp <- do.call(rbind, rr)
    gx <- seq(min(allp[, 1]) + cell / 2, max(allp[, 1]), by = cell)
    gy <- seq(min(allp[, 2]) + cell / 2, max(allp[, 2]), by = cell)
    if (length(gx) < min(na, nb) || length(gy) < min(na, nb)) next
    px <- rep(gx, times = length(gy))
    py <- rep(gy, each = length(gx))
    inside <- rep(FALSE, length(px))
    for (r in rr) {
      for (k in seq_len(nrow(r) - 1)) {
        x1 <- r[k, 1]
        y1 <- r[k, 2]
        x2 <- r[k + 1, 1]
        y2 <- r[k + 1, 2]
        hit <- ((y1 > py) != (y2 > py)) & (px < (x2 - x1) * (py - y1) / (y2 - y1) + x1)
        inside <- xor(inside, hit)
      }
    }
    m <- matrix(as.integer(inside), nrow = length(gx))
    S <- matrix(0L, nrow(m) + 1, ncol(m) + 1)
    S[-1, -1] <- t(apply(apply(m, 2, cumsum), 1, cumsum))
    win <- function(w, h) {
      if (nrow(m) < w || ncol(m) < h) return(FALSE)
      i1 <- seq_len(nrow(m) - w + 1)
      j1 <- seq_len(ncol(m) - h + 1)
      tot <- S[i1 + w, j1 + h, drop = FALSE] - S[i1, j1 + h, drop = FALSE] -
        S[i1 + w, j1, drop = FALSE] + S[i1, j1, drop = FALSE]
      any(tot == w * h)
    }
    if (win(na, nb) || win(nb, na)) return(TRUE)
  }
  FALSE
}
