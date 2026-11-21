# Boundaries cut where a rule switches at a distance from the road. Fixture
# lot P1: x 20-40, y 0-30, road along y = 0, so its sides run 30 m back.

test_that("a side boundary is cut where it crosses a frontage-distance trigger", {
  rb <- set_rule(fixture_rulebook(), "zones.A.setbacks",
                 list(list(kind = "yard", distance = 3, boundaries = list("side"),
                           when = list(within_frontage = 20), source = "front part"),
                      list(kind = "yard", distance = 1, boundaries = list("side"),
                           when = list(beyond_frontage = 20), source = "back part")),
                 validate = FALSE)
  sc <- scenario("T", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
  env <- build_envelopes(sc, keep_setbacks = TRUE)
  sb <- env$setbacks[env$setbacks$site_id == "P1" & env$setbacks$storey == 1, ]
  cut <- sb[grepl("~", sb$segment_id), ]
  # Each side is two pieces: 3 m for the first 20 m, 1 m behind.
  expect_identical(nrow(cut), 4L)
  expect_setequal(cut$setback, c(3, 3, 1, 1))
  # Footprint: 20 m wide, less 3 m each side for 20 m and 1 m each side for 10 m.
  expect_equal(env$stack$clipped_area[env$stack$site_id == "P1" & env$stack$storey == 1],
               (20 - 6) * 20 + (20 - 2) * 10)
  ex <- explain_site(estimate_capacity(set_conversion(sc$rulebook, conversion(dwelling_size = 100)) |>
                                         (\(r) scenario_change(sc, "T2", rulebook = r))()), "P1")
  expect_true(any(grepl("~1$", ex$boundaries$segment_id)))
  expect_false(anyNA(ex$setbacks$boundary_class))
})

test_that("segments not crossing a trigger are left whole", {
  rb <- set_rule(fixture_rulebook(), "zones.A.setbacks",
                 list(list(kind = "yard", distance = 2, boundaries = list("side"),
                           when = list(within_frontage = 40), source = "y")),
                 validate = FALSE)
  sc <- scenario("T", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
  env <- build_envelopes(sc, keep_setbacks = TRUE)
  expect_false(any(grepl("~", env$setbacks$segment_id)))
})
