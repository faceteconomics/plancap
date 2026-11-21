# Access to rear sites. Road along y = -20..0.
#   F1 x 0-20, y 0-30 fronts the road; R1 x 0-20, y 30-60 is behind it,
#   reached by an access lot L x 20-23.5, y 0-60 (another parcel, not a site).
#   PH x 30-50, y 30-60 with a 3 m leg x 30-33, y 0-30 (a pan-handle).
#   R2 x 60-80, y 30-60, reached by an easement x 57-60, y 0-30.

access_parcels <- function() {
  ph <- sf::st_union(sf::st_sfc(rect(30, 30, 50, 60), rect(30, 0, 33, 30)))[[1]]
  sf::st_sf(parcel_id = c("F1", "R1", "PH", "R2"),
            geometry = sf::st_sfc(rect(0, 0, 20, 30), rect(0, 30, 20, 60), ph, rect(60, 30, 80, 60),
                                  crs = NZTM))
}
access_lot <- function() sf::st_sf(id = "L", geometry = sf::st_sfc(rect(20, 0, 23.5, 60), crs = NZTM))
access_easement <- function() sf::st_sf(id = "E", geometry = sf::st_sfc(rect(57, 0, 60, 30), crs = NZTM))

test_that("rear sites are measured by entrance strip, access lot and easement", {
  s <- access_parcels()
  names(s)[1] <- "site_id"
  a <- find_access_widths(s, fixture_road(), easements = access_easement(), other_parcels = access_lot())
  a <- a[match(c("F1", "R1", "PH", "R2"), a$site_id), ]
  expect_identical(a$access_method, c("frontage", "access_lot", "frontage", "easement"))
  expect_equal(a$access_width, c(20, 3.5, 3, 3))
  expect_true(all(a$is_rear[2:4]))
})

test_that("without the layers a rear site has no measurable access", {
  s <- access_parcels()
  names(s)[1] <- "site_id"
  a <- find_access_widths(s, fixture_road())
  expect_true(is.na(a$access_width[a$site_id == "R1"]))
  expect_identical(a$access_method[a$site_id == "R2"], "none")
})

test_that("an easement over a site's own driveway is not counted twice", {
  s <- access_parcels()
  names(s)[1] <- "site_id"
  over_leg <- sf::st_sf(id = "E2", geometry = sf::st_sfc(rect(30, 0, 33.5, 31), crs = NZTM))
  a <- find_access_widths(s, fixture_road(), easements = over_leg)
  # The 3 m leg and a 3.5 m easement laid over it: the larger, not 6.5 m.
  expect_equal(a$access_width[a$site_id == "PH"], 3.5)
})

test_that("the access width table reads the measured width", {
  rb <- set_conversion(fixture_rulebook(), conversion(dwelling_size = 100)) |>
    set_rule("zones.A.density", list(access_width = list(list(min = 0, max = 3.5, max_dwellings = 2),
                                                          list(min = 3.5, max_dwellings = 5)),
                                     source = "a"))
  sc <- scenario("A", rb, parcels = access_parcels(), roads = fixture_road(),
                 zoning = fixture_zoning(split = 300), easements = access_easement(),
                 other_parcels = access_lot())
  cap <- sf::st_drop_geometry(estimate_capacity(sc)$sites)
  cap <- cap[match(c("R1", "PH", "R2"), cap$site_id), ]
  expect_identical(cap$dwellings, c(5L, 2L, 2L))
  expect_identical(cap$access_method, c("access_lot", "frontage", "easement"))
  none <- estimate_capacity(scenario_change(sc, "N", easements = NULL, other_parcels = NULL))
  r1 <- none$sites[none$sites$site_id == "R1", ]
  expect_true(r1$access_unmeasured)
  expect_gt(r1$dwellings, 5L)
})

test_that("pieces of one landholding share its best access", {
  p <- access_parcels()
  p$holding <- c("H1", "H1", "PH", "R2")
  sc <- scenario("H", fixture_rulebook(), parcels = p, roads = fixture_road(),
                 zoning = fixture_zoning(split = 300), landholding = "holding")
  s <- prepare_sites(sc)$sites
  r1 <- s[s$site_id == "R1", ]
  expect_equal(r1$access_width, 20)
  expect_identical(r1$access_method, "sibling")
  expect_identical(s$access_method[s$site_id == "R2"], "none")
})
