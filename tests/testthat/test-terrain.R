# Terrain and towers. Fixture lot P1: x 20-40, y 0-30, road along y = 0;
# zone A 8 m in two 4 m storeys.

ground_of <- function(f) {
  # Ground levels for every fixture parcel from a function of x and y: the
  # mean along each boundary segment (exact for a linear f) and the site mean.
  p <- fixture_parcels()
  names(p)[1] <- "site_id"
  pg <- parcel_geometry(p)
  seg <- pg$segments
  seq <- as.integer(sub("^.*-", "", seg$segment_id))
  list(segments = data.frame(site_id = seg$site_id, seq = seq,
                             ground = f((seg$x0 + seg$x1) / 2, (seg$y0 + seg$y1) / 2)),
       sites = data.frame(site_id = p$site_id,
                          ground_mean = vapply(seq_len(nrow(p)), function(i) {
                            cc <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(p)[i]))
                            f(cc[1], cc[2])
                          }, 0)))
}
plane_rb <- function() {
  set_rule(fixture_rulebook(), "zones.A.setbacks",
           list(list(kind = "plane", angle_deg = 45, start_height = 2.5,
                     boundaries = list("side", "rear"), source = "p")), validate = FALSE)
}
p1_sb <- function(env, storey = 1) {
  sb <- env$setbacks[env$setbacks$site_id == "P1" & env$setbacks$storey == storey, ]
  sb[order(sb$segment_id), ]
}

test_that("a plane on rising ground is slowed by the slope (capacityengine hirb_setback)", {
  p <- plane(45, start_height = 2.5, boundaries = "side")
  expect_equal(setback_distance(p, 5, slope_in = 0.1), (5 - 2.5) / (1 - 0.1))
  # The slope can never make the plane steeper than a tenth of its own rise.
  expect_equal(setback_distance(p, 5, slope_in = 2), 2.5 / 0.1)
  p_in <- plane(45, start_height = 2.5, boundaries = "side", set_in = 1)
  expect_equal(setback_distance(p_in, 5, slope_in = 0.1), 1 + (5 - 2.5 + 0.1) / 0.9)
})

test_that("level ground changes nothing", {
  sc <- scenario("F", plane_rb(), parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
  flat <- build_envelopes(sc)
  lvl <- build_envelopes(scenario_change(sc, "L", ground = ground_of(function(x, y) 0 * x + 10)))
  expect_equal(lvl$stack$clipped_area, flat$stack$clipped_area)
})

test_that("on flat terrain a boundary lower than the site takes a deeper setback", {
  rb <- set_defaults(plane_rb(), terrain = "flat")
  sc <- scenario("F", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning(),
                 ground = ground_of(function(x, y) 10 + 0.1 * x))
  env <- build_envelopes(sc, keep_setbacks = TRUE)
  sb <- p1_sb(env)
  seg <- sf::st_drop_geometry(prepare_sites(sc)$segments)
  sb$x <- seg$x0[match(sb$segment_id, seg$segment_id)]
  sb$cls <- seg$boundary_class[match(sb$segment_id, seg$segment_id)]
  # Site mean ground 13 m (centroid x = 30). The west side (x = 20, ground 12)
  # sees the building 1 m taller, the east side (x = 40, ground 14) 1 m lower.
  west <- sb$setback[sb$cls == "side" & sb$x == 20]
  east <- sb$setback[sb$cls == "side" & sb$x == 40]
  expect_equal(west, (4 + 1 - 2.5) / 1)
  expect_equal(east, (4 - 1 - 2.5) / 1)
})

test_that("stepped terrain fits each site's ground plane and uses its slope", {
  g <- ground_of(function(x, y) 10 + 0.1 * x)
  seg <- data.frame(boundary_class = "side")
  sc <- scenario("S", plane_rb(), parcels = fixture_parcels(), roads = fixture_road(),
                 zoning = fixture_zoning(), ground = g)
  env <- build_envelopes(sc, keep_setbacks = TRUE)
  sb <- p1_sb(env)
  segs <- sf::st_drop_geometry(prepare_sites(sc)$segments)
  sb$x <- segs$x0[match(sb$segment_id, segs$segment_id)]
  sb$cls <- segs$boundary_class[match(sb$segment_id, segs$segment_id)]
  # The plane through the boundary ground is exact (z = 10 + 0.1 x), so the
  # offset at each side is zero; the ground rises 0.1 into the site on the
  # west side and falls 0.1 on the east.
  west <- sb$setback[sb$cls == "side" & sb$x == 20]
  east <- sb$setback[sb$cls == "side" & sb$x == 40]
  expect_equal(west, (4 - 2.5) / (1 - 0.1))
  expect_equal(east, (4 - 2.5) / (1 + 0.1))
  pl <- ground_planes(geos::as_geos_geometry(prepare_sites(sc)$segments), match(segs$site_id, unique(segs$site_id)),
                      segs$ground, geos::as_geos_geometry(sf::st_geometry(prepare_sites(sc)$sites)))
  expect_equal(pl$gx[1], 0.1, tolerance = 1e-9)
  expect_equal(pl$gy[1], 0, tolerance = 1e-9)
})

test_that("near-straight pieces of one boundary are one run", {
  sq <- sf::st_polygon(list(rbind(c(0, 0), c(10, 0), c(20, 0.1), c(20, 20), c(0, 20), c(0, 0))))
  sg <- geos::as_geos_geometry(sf::st_sfc(sq, crs = NZTM))
  seg <- explode_segments(sg, "S")
  g <- seg$geom
  runs <- boundary_runs(g, rep(1L, length(g)), rep("side", length(g)), 5)
  expect_identical(runs[1], runs[2])      # a 0.6 degree turn
  expect_false(runs[2] == runs[3])        # a right angle
  expect_identical(length(unique(boundary_runs(g, rep(1L, length(g)), c("road", "side", "side", "side", "side"), 5))), 5L)
})

test_that("a tower floorplate limit caps the storeys above the tower threshold", {
  rb <- fixture_rulebook() |>
    set_rule("zones.B.height", list(value = 20, storeys = 5, source = "h")) |>
    set_rule("zones.B.form", list(max_tower_floorplate = 250, tower_above_height = 9, source = "t"))
  st <- build_envelopes(scenario("T", rb, parcels = fixture_parcels(), roads = fixture_road(),
                                 zoning = fixture_zoning()))$stack
  p2 <- st[st$site_id == "P2", ]
  expect_equal(p2$enabled_area, c(600, 600, 250, 250, 250))
  expect_identical(p2$binding[3], "tower_floorplate")
  rb2 <- set_rule(rb, "zones.B.form.max_tower_dimension", 25)
  e2 <- build_envelopes(scenario("T2", rb2, parcels = fixture_parcels(), roads = fixture_road(),
                                 zoning = fixture_zoning()))
  expect_identical(e2$report$tower_controls_unmodelled, 3L)
})

test_that("ground tables may match segments by position instead of sequence", {
  g <- ground_of(function(x, y) 10 + 0.1 * x)
  p <- fixture_parcels()
  names(p)[1] <- "site_id"
  seg <- parcel_geometry(p)$segments
  # The same levels keyed by midpoint, with the sequence numbers scrambled.
  pos <- data.frame(site_id = seg$site_id, seq = rev(g$segments$seq),
                    x = (seg$x0 + seg$x1) / 2, y = (seg$y0 + seg$y1) / 2, ground = g$segments$ground)
  by_seq <- scenario("S", plane_rb(), parcels = fixture_parcels(), roads = fixture_road(),
                     zoning = fixture_zoning(), ground = g)
  by_pos <- scenario_change(by_seq, "P", ground = list(sites = g$sites, segments = pos))
  expect_equal(prepare_sites(by_pos)$segments$ground, prepare_sites(by_seq)$segments$ground)
})
