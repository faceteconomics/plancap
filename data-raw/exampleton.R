# Build the Exampleton synthetic town.
#
# Run from the package root:  Rscript data-raw/exampleton.R
# Writes inst/extdata/exampleton.gpkg and inst/extdata/exampleton_dem.tif.
# Deterministic: the same seed always gives the same town.
#
# The town is a grid of blocks in NZTM (EPSG:2193), offset into the open sea
# about 250 km east of the North Island so it cannot be read as a real place.
# Local coordinates run from (0, 0) at the south-west corner and are shifted
# by (ORIGIN_X, ORIGIN_Y) at the end.

suppressPackageStartupMessages({
  library(sf)
  library(terra)
})

set.seed(20261120)
CRS <- 2193
ORIGIN_X <- 2200000
ORIGIN_Y <- 5600000

# ---- Grid ------------------------------------------------------------------

nx <- 9                     # block columns
ny <- 8                     # block rows
block_w <- 160
road_w <- rep(20, nx + 1)   # road gap before each column, plus the east edge
road_w[5] <- 30             # Main Street, the wide one (between columns 4 and 5)
reserve_h <- 40             # river reserve along the south edge
row_h <- c(50, rep(100, ny - 1))  # row 1 is one lot deep, backing onto the reserve
road_h <- 20                # east-west roads, one above each row

x_left <- cumsum(road_w[1:nx]) + (seq_len(nx) - 1) * block_w
W <- sum(road_w) + nx * block_w
y_bottom <- numeric(ny)
y_bottom[1] <- reserve_h
for (j in 2:ny) y_bottom[j] <- y_bottom[j - 1] + row_h[j - 1] + road_h
H <- y_bottom[ny] + row_h[ny] + road_h

rect <- function(x0, y0, x1, y1) {
  st_polygon(list(matrix(c(x0, y0, x1, y0, x1, y1, x0, y1, x0, y0),
                         ncol = 2, byrow = TRUE)))
}
poly <- function(...) {
  m <- matrix(c(...), ncol = 2, byrow = TRUE)
  st_polygon(list(rbind(m, m[1, ])))
}

# ---- Zones by block ---------------------------------------------------------

cx <- x_left[5] - road_w[5] / 2          # Main Street centreline
cy <- y_bottom[5] - road_h / 2           # the road between rows 4 and 5

blocks <- expand.grid(i = seq_len(nx), j = seq_len(ny))
blocks$x0 <- x_left[blocks$i]
blocks$x1 <- blocks$x0 + block_w
blocks$y0 <- y_bottom[blocks$j]
blocks$y1 <- blocks$y0 + row_h[blocks$j]
blocks$dist <- sqrt(((blocks$x0 + blocks$x1) / 2 - cx)^2 +
                    ((blocks$y0 + blocks$y1) / 2 - cy)^2)

blocks$zone <- ifelse(blocks$dist < 420, "HDR", ifelse(blocks$dist < 800, "MDR", "LDR"))
is_ij <- function(ii, jj) blocks$i %in% ii & blocks$j %in% jj
blocks$zone[is_ij(4:5, c(3, 6)) | is_ij(c(3, 6), 4:5)] <- "MU"
blocks$zone[is_ij(4:5, 4:5)] <- "TC"
blocks$zone[is_ij(8:9, 1:2)] <- "IND"
blocks$zone[is_ij(2, 6)] <- "OS"
blocks$layout <- "two_row"
blocks$layout[blocks$j == 1] <- "one_row"
blocks$layout[is_ij(7, 7)] <- "through"
blocks$layout[blocks$zone == "OS"] <- "park"
split_block <- which(is_ij(7, 5))        # west part HDR, east part MDR
blocks$zone[split_block] <- "HDR"

width_range <- list(LDR = c(18, 26), MDR = c(14, 22), HDR = c(14, 22),
                    MU = c(10, 20), TC = c(10, 20), IND = c(35, 50))
rear_prob <- c(LDR = 0.35, MDR = 0.30, HDR = 0.15, MU = 0, TC = 0, IND = 0)

# ---- Lots ------------------------------------------------------------------

widths <- function(len, range) {
  n <- max(1, round(len / mean(range)))
  w <- runif(n, range[1], range[2])
  w / sum(w) * len
}

# One row of lots between y0 and y1, fronting the road on `front` ("top" or
# "bottom"). Some lots become a front lot plus a rear lot with an access leg.
lot_row <- function(x0, x1, y0, y1, zone, front, large_first = FALSE,
                    allow_rear = TRUE) {
  w <- widths(x1 - x0, width_range[[zone]])
  if (large_first) {                     # one amalgamated large site
    w <- c(60, widths(x1 - x0 - 60, width_range[[zone]]))
  }
  edges <- x0 + c(0, cumsum(w))
  out <- list()
  for (k in seq_along(w)) {
    a <- edges[k]; b <- edges[k + 1]
    rear <- allow_rear && (b - a) >= 15 && runif(1) < rear_prob[[zone]] &&
      (y1 - y0) >= 45
    if (!rear) {
      out[[length(out) + 1]] <- list(geom = rect(a, y0, b, y1), kind = "front")
      next
    }
    leg <- 4
    fd <- 22                             # depth of the front lot
    leg_west <- runif(1) < 0.5
    la <- if (leg_west) a else b - leg   # leg strip x range
    lb <- la + leg
    fa <- if (leg_west) lb else a        # front lot x range
    fb <- if (leg_west) b else la
    if (front == "top") {
      f <- rect(fa, y1 - fd, fb, y1)
      r <- if (leg_west) {
        poly(a, y0, b, y0, b, y1 - fd, lb, y1 - fd, lb, y1, a, y1)
      } else {
        poly(a, y0, b, y0, b, y1, la, y1, la, y1 - fd, a, y1 - fd)
      }
    } else {
      f <- rect(fa, y0, fb, y0 + fd)
      r <- if (leg_west) {
        poly(a, y0, lb, y0, lb, y0 + fd, b, y0 + fd, b, y1, a, y1)
      } else {
        poly(a, y0 + fd, la, y0 + fd, la, y0, b, y0, b, y1, a, y1)
      }
    }
    out[[length(out) + 1]] <- list(geom = f, kind = "front")
    out[[length(out) + 1]] <- list(geom = r, kind = "rear")
  }
  out
}

lots <- list()
for (b in seq_len(nrow(blocks))) {
  bk <- blocks[b, ]
  zone_for_lots <- if (bk$zone == "OS") "LDR" else bk$zone
  rows <- switch(bk$layout,
    park = list(list(geom = rect(bk$x0, bk$y0, bk$x1, bk$y1), kind = "reserve")),
    one_row = lot_row(bk$x0, bk$x1, bk$y0, bk$y1, zone_for_lots, "top"),
    through = lapply(lot_row(bk$x0, bk$x1, bk$y0, bk$y1, "MDR", "top",
                             allow_rear = FALSE),
                     function(l) { l$kind <- "through"; l }),
    two_row = {
      ym <- (bk$y0 + bk$y1) / 2
      large <- bk$zone == "TC" && bk$i == 4 && bk$j == 5
      c(lot_row(bk$x0, bk$x1, ym, bk$y1, zone_for_lots, "top", large_first = large),
        lot_row(bk$x0, bk$x1, bk$y0, ym, zone_for_lots, "bottom"))
    }
  )
  lots <- c(lots, rows)
}

land <- st_sf(
  kind = vapply(lots, `[[`, "", "kind"),
  geometry = st_sfc(lapply(lots, `[[`, "geom"))
)
land$parcel_type <- ifelse(land$kind == "reserve", "reserve", "land")

# ---- Roads and reserve ------------------------------------------------------

h_roads <- lapply(seq_len(ny), function(j) {
  y0 <- y_bottom[j] + row_h[j]
  rect(0, y0, W, y0 + road_h)
})
v_roads <- list()
for (j in seq_len(ny)) {
  y0 <- y_bottom[j]
  y1 <- y0 + row_h[j]
  xs <- c(0, x_left + block_w)
  for (k in seq_len(nx + 1)) {
    v_roads[[length(v_roads) + 1]] <- rect(xs[k], y0, xs[k] + road_w[k], y1)
  }
}
roads <- st_sf(kind = "road", parcel_type = "road",
               geometry = st_sfc(c(h_roads, v_roads)))
reserve <- st_sf(kind = "reserve", parcel_type = "reserve",
                 geometry = st_sfc(list(rect(0, 0, W, reserve_h))))

parcels <- rbind(land, roads, reserve)
parcels$parcel_id <- sprintf("P%05d", seq_len(nrow(parcels)))
parcels$lot_form <- parcels$kind
parcels$title_id <- parcels$parcel_id
# A few pairs of neighbouring land lots held on one title (amalgamation tests)
pair_from <- sample(which(parcels$kind == "front" & c(parcels$kind[-1], NA) == "front"), 6)
parcels$title_id[pair_from + 1] <- parcels$title_id[pair_from]
parcels <- parcels[, c("parcel_id", "title_id", "parcel_type", "lot_form")]

# ---- Road centrelines -------------------------------------------------------

street_names <- c("Harbour", "Kauri", "Totara", "Rimu", "Matai", "Miro", "Tawa", "Hinau")
road_names <- c("Beach", "Ferry", "Quarry", "Mill", "Main", "Church", "School",
                "Station", "Ridge", "Summit")
h_lines <- lapply(seq_len(ny), function(j) {
  y <- y_bottom[j] + row_h[j] + road_h / 2
  st_linestring(matrix(c(0, y, W, y), ncol = 2, byrow = TRUE))
})
xs <- c(0, x_left + block_w)
v_lines <- lapply(seq_len(nx + 1), function(k) {
  x <- xs[k] + road_w[k] / 2
  st_linestring(matrix(c(x, reserve_h, x, H), ncol = 2, byrow = TRUE))
})
road_centrelines <- st_sf(
  name = c(paste(street_names, "Street"),
           ifelse(road_names == "Main", "Main Street", paste(road_names, "Road"))),
  width_m = c(rep(road_h, ny), road_w),
  geometry = st_sfc(c(h_lines, v_lines))
)

# ---- Zoning ----------------------------------------------------------------

zone_feats <- lapply(seq_len(nrow(blocks)), function(b) {
  bk <- blocks[b, ]
  if (b == split_block) {
    xm <- bk$x0 + 75                     # deliberately not on a lot boundary
    return(list(list(zone = "HDR", geom = rect(bk$x0, bk$y0, xm, bk$y1)),
                list(zone = "MDR", geom = rect(xm, bk$y0, bk$x1, bk$y1))))
  }
  list(list(zone = bk$zone, geom = rect(bk$x0, bk$y0, bk$x1, bk$y1)))
})
zone_feats <- c(unlist(zone_feats, recursive = FALSE),
                list(list(zone = "OS", geom = rect(0, 0, W, reserve_h))))
zone_raw <- st_sf(zone = vapply(zone_feats, `[[`, "", "zone"),
                  geometry = st_sfc(lapply(zone_feats, `[[`, "geom")))
zone_labels <- c(TC = "Town Centre", MU = "Mixed Use", HDR = "High Density Residential",
                 MDR = "Medium Density Residential", LDR = "Low Density Residential",
                 IND = "Industrial", OS = "Open Space")
zoning <- do.call(rbind, lapply(names(zone_labels), function(z) {
  st_sf(zone = z, label = zone_labels[[z]],
        geometry = st_union(zone_raw$geometry[zone_raw$zone == z]))
}))

# ---- Overlays ---------------------------------------------------------------

block_union <- function(sel, pad = 0) {
  g <- st_union(st_sfc(lapply(which(sel), function(b) {
    bk <- blocks[b, ]
    rect(bk$x0 - pad, bk$y0 - pad, bk$x1 + pad, bk$y1 + pad)
  })))
  g
}
height_areas <- st_sf(
  name = c("Centre height area", "Frame height area"),
  max_height_m = c(27, 18),
  geometry = c(block_union(blocks$zone == "TC", pad = 5),
               block_union(blocks$zone == "MU", pad = 5))
)

river_x <- seq(0, W, by = 10)
river <- st_linestring(cbind(river_x, 20 + 8 * sin(2 * pi * river_x / 400)))
water <- st_sf(name = "Exampleton Stream", type = "river", width_m = 6,
               geometry = st_sfc(river))

town <- rect(0, 0, W, H)
flood_hazard <- st_sf(name = "Stream flood plain", hazard = "flood",
                      geometry = st_sfc(st_intersection(st_buffer(river, 45), town)))

tc_lots <- which(parcels$parcel_type == "land" &
                 lengths(st_within(st_centroid(parcels$geometry),
                                   block_union(blocks$zone == "TC"))) > 0)
heritage <- st_sf(name = paste("Heritage place", 1:3),
                  geometry = st_buffer(parcels$geometry[sample(tc_lots, 3)], -0.5))

pb <- blocks[is_ij(3, 2), ]
pm <- (pb$x0 + pb$x1) / 2
precincts <- st_sf(
  precinct = "Quarry Precinct",
  sub_precinct = c("A", "B"),
  geometry = st_sfc(rect(pb$x0, pb$y0, pm, pb$y1), rect(pm, pb$y0, pb$x1, pb$y1))
)

transit <- st_sf(name = "Exampleton Station", mode = "rail",
                 geometry = st_sfc(st_point(c(cx, cy))))

land_idx <- which(parcels$parcel_type == "land")
tree_lots <- sample(land_idx, 40)
trees <- st_sf(
  tree_id = sprintf("T%03d", seq_along(tree_lots)),
  dbh_m = round(runif(length(tree_lots), 0.3, 1.2), 2),
  protected = runif(length(tree_lots)) < 0.25,
  geometry = st_sfc(lapply(tree_lots, function(k) {
    st_point(st_coordinates(st_point_on_surface(parcels$geometry[k]))[1, 1:2] +
               runif(2, -3, 3))
  }))
)
# Keep every tree inside its lot
inside <- lengths(st_within(trees$geometry, parcels$geometry[tree_lots])) > 0
trees <- trees[inside, ]
# Protection: a status a rule can filter on, and a root-zone radius of 12
# trunk diameters (as AS 4970 uses), capped at 15 m.
trees$status <- ifelse(trees$protected, "protected", "unprotected")
trees$protection_radius_m <- pmin(round(12 * trees$dbh_m, 1), 15)
trees <- trees[, c("tree_id", "dbh_m", "status", "protection_radius_m")]

# ---- Existing buildings -----------------------------------------------------

lot_zone <- zoning$zone[st_nearest_feature(st_point_on_surface(parcels$geometry), zoning)]
built <- land_idx[runif(length(land_idx)) > 0.1]       # about 10% vacant
bldg <- lapply(built, function(k) {
  g <- parcels$geometry[[k]]
  inner <- st_buffer(g, -2)
  if (st_is_empty(inner)) return(NULL)
  c0 <- st_coordinates(st_point_on_surface(g))[1, 1:2]
  half <- sqrt(as.numeric(st_area(g))) * runif(1, 0.25, 0.4)
  fp <- st_intersection(inner, rect(c0[1] - half, c0[2] - half, c0[1] + half, c0[2] + half))
  if (st_is_empty(fp)) return(NULL)
  if (inherits(fp, "MULTIPOLYGON")) {
    parts <- lapply(fp, st_polygon)
    fp <- parts[[which.max(vapply(parts, st_area, numeric(1)))]]
  }
  if (!inherits(fp, "POLYGON") || st_area(fp) < 30) return(NULL)
  fp
})
keep <- !vapply(bldg, is.null, logical(1))
built <- built[keep]
zb <- lot_zone[built]
storeys <- ifelse(zb %in% c("TC", "MU"), sample(1:4, length(zb), TRUE),
           ifelse(zb == "IND", 1L, sample(1:2, length(zb), TRUE, prob = c(0.7, 0.3))))
buildings <- st_sf(
  building_id = sprintf("B%05d", seq_along(built)),
  parcel_id = parcels$parcel_id[built],
  storeys = as.integer(storeys),
  geometry = st_sfc(bldg[keep])
)

# ---- Shift into place and write --------------------------------------------

shift <- function(x) {
  st_geometry(x) <- st_geometry(x) + c(ORIGIN_X, ORIGIN_Y)
  st_crs(x) <- CRS
  x
}
layers <- list(parcels = parcels, road_centrelines = road_centrelines, zoning = zoning,
               height_areas = height_areas, flood_hazard = flood_hazard,
               heritage = heritage, precincts = precincts, water = water,
               transit = transit, trees = trees, buildings = buildings)
layers <- lapply(layers, shift)

stopifnot(all(st_is_valid(layers$parcels)), all(st_is_valid(layers$buildings)))

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
gpkg <- "inst/extdata/exampleton.gpkg"
if (file.exists(gpkg)) invisible(file.remove(gpkg))
for (nm in names(layers)) {
  st_write(layers[[nm]], gpkg, layer = nm, quiet = TRUE)
}

# ---- Ground surface ---------------------------------------------------------

dem <- rast(xmin = ORIGIN_X, xmax = ORIGIN_X + W, ymin = ORIGIN_Y, ymax = ORIGIN_Y + H,
            resolution = 5, crs = "EPSG:2193")
xy <- xyFromCell(dem, seq_len(ncell(dem)))
lx <- xy[, 1] - ORIGIN_X
ly <- xy[, 2] - ORIGIN_Y
z <- 5 + 0.015 * ly +
  35 * exp(-((lx - 0.8 * W)^2 + (ly - 0.8 * H)^2) / (2 * 120^2)) -
  3 * exp(-(ly - 20)^2 / (2 * 15^2))
values(dem) <- round(z, 2)
names(dem) <- "ground_m"
writeRaster(dem, "inst/extdata/exampleton_dem.tif", overwrite = TRUE,
            datatype = "FLT4S", gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"))

cat(sprintf("Parcels: %d (land %d, road %d, reserve %d); rear lots %d; buildings %d; trees %d\n",
            nrow(parcels), sum(parcels$parcel_type == "land"),
            sum(parcels$parcel_type == "road"), sum(parcels$parcel_type == "reserve"),
            sum(parcels$lot_form == "rear"), nrow(buildings), nrow(trees)))
cat(sprintf("Extent: %.0f x %.0f m; gpkg %.2f MB; dem %.2f MB\n", W, H,
            file.size(gpkg) / 1e6, file.size("inst/extdata/exampleton_dem.tif") / 1e6))
