# A front yard set from the neighbours' existing setbacks. Fixture lots along
# the road (y = -20..0): P7 x 0-20, P1 x 20-40, P2 x 40-60, P4 x 60-80,
# P5 x 80-100. Houses 10 m square, set back 4 m (P7), 6 m (P2) and 8 m (P4);
# P5 has only a 20 m2 shed; P1, the subject, is vacant.

front_buildings <- function() {
  house <- function(x0, d, w = 10) rect(x0 + 5, d, x0 + 5 + w, d + w)
  sf::st_sf(id = 1:4, geometry = sf::st_sfc(house(0, 4), house(40, 6), house(60, 8),
                                             house(80, 3, w = sqrt(20)), crs = NZTM))
}
front_streets <- function() {
  sf::st_sf(name = "Main Street", geometry = sf::st_sfc(sf::st_linestring(rbind(c(-200, -10), c(300, -10))),
                                                         crs = NZTM))
}
front_rb <- function() {
  set_rule(fixture_rulebook(), "zones.A.setbacks",
           list(list(kind = "yard", value_from = "existing_front_setback", boundaries = list("road"),
                     source = "D18.6.1.3.1")), validate = FALSE)
}

test_that("three neighbours either side, or six on one, by street position", {
  s <- fixture_parcels()
  names(s)[1] <- "site_id"
  m <- find_existing_front_setbacks(s, fixture_road(), front_buildings(), front_streets())
  p1 <- m[m$site_id == "P1", ]
  # West: only P7. East: P2, P4 and P5 make up the six. P5's shed is no
  # dwelling: (4 + 6 + 8) / 3.
  expect_equal(p1$setback, 6)
  expect_identical(p1$n, 3L)
  expect_match(p1$neighbours, "P7:4.0;P2:6.0;P4:8.0;P5:none", fixed = TRUE)
  # P7 at the street end: P1 (vacant), P2, P4, P5 on one side.
  expect_equal(m$setback[m$site_id == "P7"], 7)
})

test_that("the yard is a rule and validates", {
  y <- yard(value_from = "existing_front_setback", boundaries = "road", source = "s")
  expect_identical(y$value_from, "existing_front_setback")
  expect_true(is.na(setback_distance(y, 3)))
  expect_equal(setback_distance(y, c(3, 6), measured = 5.5), c(5.5, 5.5))
  expect_error(yard(3, "road", value_from = "existing_front_setback"), "not both")
  rb <- add_zone(rulebook("V"), zone("Z", method = "volumetric", height = height_limit(8, source = "h"),
                                     setbacks = list(y), source = "z"))
  expect_true(validate_rulebook(rb)$valid)
})

test_that("the envelope takes the measured yard, and reports where it cannot", {
  sc <- scenario("F", front_rb(), parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning(),
                 buildings = front_buildings(), streets = front_streets())
  env <- build_envelopes(sc, keep_setbacks = TRUE)
  p1 <- env$stack[env$stack$site_id == "P1", ]
  expect_equal(p1$enabled_area, c(20 * 24, 20 * 24))
  sb <- env$setbacks[env$setbacks$site_id == "P1" & env$setbacks$setback > 0, ]
  expect_true(all(sb$source == "D18.6.1.3.1"))
  expect_identical(env$report$front_yard_unmeasured, 0L)
  # Without building outlines: not applied, and reported.
  bare <- build_envelopes(scenario_change(sc, "B", buildings = NULL))
  expect_equal(bare$stack$enabled_area[bare$stack$site_id == "P1"], c(600, 600))
  expect_identical(bare$report$front_yard_unmeasured, 2L)
  expect_true(bare$report$front_yard_inputs_missing)
})
