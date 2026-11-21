# The site shape factor on the fixture. P1 is 20 x 30 m with a road along
# y = 0; zone A is made a density zone with a 100 m2 vacant site minimum.

shape_rb <- function(rect = c(8, 15), yards = TRUE) {
  rb <- set_conversion(fixture_rulebook(), conversion(dwelling_size = 100)) |>
    set_rule("zones.A.method", "density", validate = FALSE) |>
    set_rule("zones.A.density", list(vacant_site_min_area = 100, source = "d")) |>
    set_rule("zones.A.form", list(site_shape = list(width = rect[1], depth = rect[2]), source = "s"))
  if (yards) {
    rb <- set_rule(rb, "zones.A.setbacks",
                   list(list(kind = "yard", distance = 3, boundaries = list("road"), source = "y"),
                        list(kind = "yard", distance = 1, boundaries = list("side", "rear"), source = "y")),
                   validate = FALSE)
  }
  rb
}
shape_sc <- function(rb) {
  scenario("S", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
}

test_that("the rectangle is tested clear of the yards", {
  sh <- site_shape_factor(shape_sc(shape_rb()))
  p1 <- sh[sh$site_id == "P1", ]
  # Developable: x 21-39, y 3-29 (18 x 26 m).
  expect_equal(p1$developable_area, 18 * 26)
  expect_true(p1$fits)
  expect_identical(p1$decided_by, "aligned")
  expect_identical(p1$max_lots, 3L)       # floor(468 / 120)
})

test_that("a site that cannot hold the rectangle fails, and by which test", {
  sh <- site_shape_factor(shape_sc(shape_rb(c(19, 15))))
  expect_false(sh$fits[sh$site_id == "P1"])
  expect_identical(sh$decided_by[sh$site_id == "P1"], "rotated_rectangle")
  big <- site_shape_factor(shape_sc(shape_rb(c(20, 25))))
  expect_identical(big$decided_by[big$site_id == "P1"], "area")
})

test_that("the exact test finds a rectangle at an angle", {
  # A 9 x 16 m strip turned 30 degrees holds an 8 x 15 rectangle along its
  # own edges; a 7.5 m strip does not.
  strip <- function(w) {
    g <- sf::st_sfc(rect(0, 0, 16, w), crs = NZTM)
    a <- pi / 6
    geos::as_geos_geometry((g * matrix(c(cos(a), sin(a), -sin(a), cos(a)), 2)) |> sf::st_set_crs(NZTM))
  }
  expect_true(rect_fits_grid(strip(9), 15, 8, angle_step = 5, cell = 0.25))
  expect_false(rect_fits_grid(strip(7.5), 15, 8, angle_step = 5, cell = 0.25))
})

test_that("an L-shaped lot whose arms are too narrow fails the disc test", {
  L <- sf::st_polygon(list(rbind(c(0, 0), c(30, 0), c(30, 6), c(6, 6), c(6, 30), c(0, 30), c(0, 0))))
  prc <- sf::st_sf(parcel_id = "L1", geometry = sf::st_sfc(L, crs = NZTM) + c(-100, 0))
  sf::st_crs(prc) <- NZTM
  sc <- scenario("L", shape_rb(yards = FALSE), parcels = prc, roads = fixture_road(), zoning = fixture_zoning())
  sh <- site_shape_factor(sc)
  expect_false(sh$fits)
  expect_identical(sh$decided_by, "inscribed_disc")
})

test_that("estimate_capacity caps subdivision by the rectangles the site holds", {
  cap <- estimate_capacity(shape_sc(shape_rb()))
  p1 <- sf::st_drop_geometry(cap$sites)[cap$sites$site_id == "P1", ]
  expect_identical(p1$dwellings, 3L)      # 6 by the vacant site minimum
  expect_identical(p1$dwelling_binding, "site_shape_factor")
  expect_true(p1$site_shape_fits)
  no <- estimate_capacity(shape_sc(shape_rb(c(19, 15))))
  expect_identical(no$sites$dwellings[no$sites$site_id == "P1"], 1L)
  off <- estimate_capacity(shape_sc(set_defaults(shape_rb(), site_shape_factor = FALSE)))
  expect_identical(off$sites$dwellings[off$sites$site_id == "P1"], 6L)
})
