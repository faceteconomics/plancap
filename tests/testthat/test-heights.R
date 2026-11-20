# Height overlays, surfaces, building gaps and height bonuses on the fixture.
# Zone A: 8 m with no stated storeys, so 4 m storeys (8 m divided into as many
# 3 m storeys as fit, capacityengine's rule): two storeys of 600 m2 on P1.

with_overlay <- function(rb, layers, ...) {
  estimate_capacity(scenario("H", set_conversion(rb, conversion(dwelling_size = 100)),
                             parcels = fixture_parcels(), roads = fixture_road(),
                             zoning = fixture_zoning(), layers = layers), ...)
}
p1 <- function(cap) sf::st_drop_geometry(cap$sites)[cap$sites$site_id == "P1", ]
hmap <- function(h) sf::st_sf(h = h, geometry = sf::st_sfc(rect(0, 0, 40, 30), crs = NZTM))

test_that("a height cap lowers, an override replaces, a cap over no height does nothing", {
  cap_rb <- add_overlay(fixture_rulebook(), overlay("hc", "height", layer = "hm", value_field = "h", source = "x"))
  expect_identical(p1(with_overlay(cap_rb, list(hm = hmap(4))))$storeys, 1L)
  expect_identical(p1(with_overlay(cap_rb, list(hm = hmap(20))))$storeys, 2L)    # a cap never raises
  ov_rb <- add_overlay(fixture_rulebook(), overlay("hc", "height", layer = "hm", value_field = "h",
                                                   combine = "replace", source = "x"))
  expect_identical(p1(with_overlay(ov_rb, list(hm = hmap(15))))$storeys, 3L)  # 15 m in the zone's 4 m storeys
  none <- set_rule(cap_rb, "zones.A.height", list(from_overlay = "hc", source = "z"))
  none <- set_rule(none, "overlays.hc.applies_to_zones", list("B"))
  expect_identical(p1(with_overlay(none, list(hm = hmap(9))))$storeys, 0L)
})

test_that("a cap that bites only the roof allowance leaves the storeys", {
  rb <- fixture_rulebook() |>
    set_rule("zones.A.height", list(value = 9, occupiable = 8, roof_allowance = 1, storeys = 2, source = "z")) |>
    add_overlay(overlay("hc", "height", layer = "hm", value_field = "h", source = "x"))
  expect_identical(p1(with_overlay(rb, list(hm = hmap(8.5))))$storeys, 2L)
  expect_identical(p1(with_overlay(rb, list(hm = hmap(7))))$storeys, 1L)
})

test_that("a mapped total height converts to occupiable height through the table", {
  conv <- list(table = data.frame(total = c(13, 18), occupiable = c(11, 16)),
               passthrough_below = 11, passthrough_above = 27, between = "passthrough")
  expect_equal(convert_height(13, conv), 11)
  expect_equal(convert_height(10, conv), 10)
  expect_equal(convert_height(15, conv), 15)
  expect_equal(convert_height(15, utils::modifyList(conv, list(between = "interpolate"))), 13)
  rb <- add_overlay(fixture_rulebook(),
                    overlay("hvc", "height", layer = "hm", value_field = "h", combine = "replace",
                            height_conversion = conv, source = "x"))
  # 13 m total is 11 m occupiable: two 4 m storeys, where 13 m would hold three.
  expect_identical(p1(with_overlay(rb, list(hm = hmap(13))))$storeys, 2L)
})

test_that("a height surface over a whole site caps it; over part, it takes land storey by storey", {
  skip_if_not_installed("terra")
  rb <- add_overlay(fixture_rulebook(), overlay("ols", "height_surface", layer = "surf",
                                                surface_datum = "ground", source = "x"))
  full <- terra::rast(xmin = -10, xmax = 110, ymin = -10, ymax = 80, resolution = 1, crs = "EPSG:2193", vals = 4)
  expect_identical(p1(with_overlay(rb, list(surf = full)))$storeys, 1L)
  half <- terra::rast(xmin = 30, xmax = 40, ymin = 0, ymax = 30, resolution = 1, crs = "EPSG:2193", vals = 4)
  cap <- with_overlay(rb, list(surf = half))
  st <- cap$stack[cap$stack$site_id == "P1", ]
  expect_equal(st$clipped_area, c(600, 300))     # storey 2 (ceiling 6 m) loses the half under 4 m
  expect_identical(cap$envelope$report$surface_partial, 1L)
  missing <- with_overlay(rb, list())
  expect_identical(missing$envelope$report$surfaces_missing, "surf")
})

test_that("building length and separation cut gaps through the footprint", {
  rb <- set_rule(fixture_rulebook(), "zones.A.form", list(max_building_length = 10, building_separation = 2,
                                                          source = "f"))
  st <- with_overlay(rb, list())$stack
  # 20 x 30 m: gaps 2 m wide at 10-12 (across the 20 m side) and 10-12, 22-24
  # (across the 30 m side): 600 - 2*30 - 2*2*20 + 2*2*2 = 468 m2.
  expect_equal(st$clipped_area[st$site_id == "P1"][1], 468)
  above <- set_rule(rb, "zones.A.form.building_separation",
                    list(bands = list(by = "height", bands = list(list(min = 0, max = 4, value = 0),
                                                                    list(min = 4, value = 2)))))
  st2 <- with_overlay(above, list())$stack
  expect_equal(st2$clipped_area[st2$site_id == "P1"], c(600, 468))
})

test_that("a height bonus is built and reported apart", {
  rb <- add_bonus(fixture_rulebook(), bonus("tall", "height", 4, applies_to_zones = "A", source = "b"))
  cap <- with_overlay(rb, list())
  x <- p1(cap)
  expect_equal(x$floor_area, 1200)
  expect_equal(x$floor_area_with_bonus, 1800)
  expect_identical(x$dwellings_with_bonus, 18L)
  expect_identical(cap$report$height_bonus_sites, 3L)
  expect_equal(sf::st_drop_geometry(cap$sites)$floor_area_with_bonus[cap$sites$site_id == "P2"], 1800)
})
