pg <- function(parcels = fixture_parcels(), roads = fixture_road(), ...) {
  s <- parcels
  names(s)[names(s) == "parcel_id"] <- "site_id"
  parcel_geometry(s, roads = roads, ...)
}

test_that("a rectangle yields four segments", {
  p1 <- seg_of(pg()$segments, "P1")
  expect_identical(nrow(p1), 4L)
  expect_equal(sum(p1$length), 100)
})

test_that("the road-facing edge is road, the opposite edge rear, the flanks side", {
  p1 <- seg_of(pg()$segments, "P1")
  expect_equal(p1$length[p1$boundary_class == "road"], 20)
  rear <- p1[p1$boundary_class == "rear", ]
  expect_identical(nrow(rear), 1L)
  expect_equal(rear$length, 20)
  expect_equal(rear$dist_from_frontage, 30)
  expect_true(all(p1$length[p1$boundary_class == "side"] == 30))
})

test_that("frontage and the rear-site test follow the frontage threshold", {
  s <- pg()$sites
  expect_equal(s$frontage[s$site_id == "P1"], 20)
  expect_false(s$is_rear[s$site_id == "P1"])
  expect_equal(s$frontage[s$site_id == "P6"], 0)
  expect_true(s$is_rear[s$site_id == "P6"])
})

test_that("a site with no frontage is flagged and nothing on it claims to be rear", {
  x <- pg()
  expect_identical(x$sites$flag[x$sites$site_id == "P6"], "no_road_frontage")
  expect_identical(sum(seg_of(x$segments, "P6")$boundary_class == "rear"), 0L)
})

test_that("outward bearings point away from the site", {
  p1 <- seg_of(pg()$segments, "P1")
  road <- p1[p1$boundary_class == "road", ]
  rear <- p1[p1$boundary_class == "rear", ]
  expect_equal(road$outward_bearing, 180)     # the road is to the south
  expect_equal(rear$outward_bearing, 0)
  expect_setequal(round(p1$outward_bearing[p1$boundary_class == "side"]), c(90, 270))
})

test_that("classification ignores ring winding order", {
  p <- fixture_parcels()
  co <- sf::st_coordinates(p[p$parcel_id == "P1", ])[, c("X", "Y")]
  sf::st_geometry(p)[[2]] <- sf::st_polygon(list(co[rev(seq_len(nrow(co))), ]))
  p1 <- seg_of(pg(p)$segments, "P1")
  expect_identical(sum(p1$boundary_class == "road"), 1L)
  expect_identical(sum(p1$boundary_class == "rear"), 1L)
  expect_equal(p1$outward_bearing[p1$boundary_class == "road"], 180)
})

test_that("probe and ring winding agree on which way is out, even on a thin spike", {
  spike <- sf::st_polygon(list(cbind(c(0, 20, 20, 10.1, 10.1, 10, 10, 0, 0),
                                     c(0, 0, 30, 30, 35, 35, 30, 30, 0))))
  sg <- geos::as_geos_geometry(sf::st_sfc(spike, crs = NZTM))
  seg <- explode_segments(sg, "SP")
  is_spike <- (seg$x0 == 10 & seg$x1 == 10) | (seg$x0 == 10.1 & seg$x1 == 10.1)
  expect_identical(sum(is_spike), 2L)
  by_probe <- outward_bearing(seg, sg, rep(1L, nrow(seg)))$bearing
  by_wind <- outward_bearing(seg, sg, rep(1L, nrow(seg)), d0 = 1, retries = 0L)$bearing
  expect_equal(by_wind[is_spike], by_probe[is_spike])
  expect_equal(abs(diff(sort(by_probe[is_spike]))), 180)
})

test_that("a corner site has two frontage directions", {
  s <- pg(roads = fixture_road_cross())$sites
  expect_true(s$is_corner[s$site_id == "P7"])
  expect_identical(s$n_frontage_directions[s$site_id == "P7"], 2L)
  expect_false(s$is_corner[s$site_id == "P1"])
})

test_that("a site on a curved street is not a corner site", {
  arc <- function(r, a0, a1, n = 9) {
    a <- seq(a0, a1, length.out = n) * pi / 180
    cbind(r * cos(a), r * sin(a))
  }
  ring <- function(r_in, r_out) {
    m <- rbind(arc(r_out, 190, 270), arc(r_in, 270, 190))
    sf::st_polygon(list(rbind(m, m[1, , drop = FALSE])))
  }
  site <- sf::st_sf(site_id = "C1", geometry = sf::st_sfc(ring(25, 40), crs = NZTM))
  road <- sf::st_sf(geometry = sf::st_sfc(ring(40, 46), crs = NZTM))
  x <- parcel_geometry(site, roads = road)
  front <- x$segments[x$segments$boundary_class == "road", ]
  expect_gt(nrow(front), 4)
  expect_false(x$sites$is_corner)
  expect_identical(x$sites$n_frontage_directions, 1L)
})

test_that("a site between two roads is a through site, not a corner", {
  site <- sf::st_sf(site_id = "T", geometry = sf::st_sfc(rect(0, 0, 20, 40), crs = NZTM))
  roads <- sf::st_sf(geometry = sf::st_sfc(rect(-50, -20, 70, 0), rect(-50, 40, 70, 60), crs = NZTM))
  s <- parcel_geometry(site, roads = roads)$sites
  expect_true(s$is_through)
  expect_false(s$is_corner)
})

test_that("an access leg is found on a rear site and measured", {
  # A rear lot 20 x 25 behind a front lot, reached by a 4 m wide, 22 m long leg.
  rear <- sf::st_polygon(list(cbind(c(0, 4, 4, 20, 20, 0, 0), c(0, 0, 22, 22, 47, 47, 0))))
  front <- rect(4, 0, 20, 22)
  sites <- sf::st_sf(site_id = c("R", "F"), geometry = sf::st_sfc(rear, front, crs = NZTM))
  x <- parcel_geometry(sites, roads = fixture_road())
  s <- x$sites
  expect_true(s$is_rear[s$site_id == "R"])
  expect_equal(s$access_leg_area[s$site_id == "R"], 88, tolerance = 1e-6)
  expect_equal(s$net_area[s$site_id == "R"], s$area[s$site_id == "R"] - 88, tolerance = 1e-6)
  expect_equal(s$access_leg_area[s$site_id == "F"], 0)
  expect_identical(nrow(x$access_legs), 1L)
  # With legs counted in net area, net area is unchanged.
  y <- parcel_geometry(sites, roads = fixture_road(), morphology = list(exclude_access_legs = FALSE))
  expect_equal(y$sites$net_area, y$sites$area)
})

test_that("road width is measured across the road parcel", {
  s <- pg()$sites
  expect_equal(s$road_width[s$site_id == "P1"], 20, tolerance = 0.5)
  expect_identical(s$road_width_method[s$site_id == "P1"], "measured")
})

test_that("water boundaries are tagged with their distance", {
  river <- sf::st_sf(type = "river", geometry = sf::st_sfc(
    sf::st_linestring(rbind(c(-50, 80), c(150, 80))), crs = NZTM))
  x <- pg(water = river)
  p6 <- seg_of(x$segments, "P6")
  north <- p6[p6$outward_bearing == 0, ]
  expect_match(north$tags, "|riparian|", fixed = TRUE)
  expect_equal(north$water_distance, 10)
  expect_true(all(is.na(seg_of(x$segments, "P1")$water_distance)))
})

test_that("morphology settings follow rulebook, then run overrides", {
  rb <- set_morphology(fixture_rulebook(), rear_site_max_frontage = 25)
  expect_true(pg(rulebook = rb)$sites$is_rear[2])          # P1 has 20 m
  expect_false(pg(rulebook = rb, morphology = list(rear_site_max_frontage = 10))$sites$is_rear[2])
  expect_error(pg(morphology = list(nonsense = 1)), "Unknown morphology")
})

test_that("geographic coordinates are refused", {
  p <- sf::st_transform(fixture_parcels(), 4326)
  names(p)[1] <- "site_id"
  expect_error(parcel_geometry(p), "geographic")
})

test_that("a rear site's side boundaries can be rear boundaries, where the plan says so", {
  # P6 has no frontage, so it is a rear site.
  s <- fixture_parcels()
  names(s)[1] <- "site_id"
  plain <- find_side_rear(s, fixture_road())
  expect_true("side" %in% plain$boundary_class[plain$site_id == "P6"])
  rr <- find_side_rear(s, fixture_road(), morphology = list(rear_site_sides_as_rear = TRUE))
  p6 <- rr[rr$site_id == "P6", ]
  expect_false("side" %in% p6$boundary_class)
  expect_true(any(grepl("rear_site_side", p6$tags, fixed = TRUE)))
  # A site with frontage keeps its sides.
  expect_true("side" %in% rr$boundary_class[rr$site_id == "P1"])
})
