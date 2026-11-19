test_that("a yard is a fixed distance, optionally from a storey or height", {
  y <- yard(3, "road")
  expect_equal(setback_distance(y, c(0, 10)), c(3, 3))
  y2 <- yard(2, "rear", from_storey = 2)
  expect_equal(setback_distance(y2, c(3, 6), storey = c(1, 2)), c(0, 2))
  u <- upper_level_setback(3, "road", above_height = 16)
  expect_equal(setback_distance(u, c(15, 17)), c(0, 3))
})

test_that("a plane matches capacityengine's hirb_setback formula", {
  # set_in + max(0, (h - start) / tan(angle))
  p <- plane(45, start_height = 2.5, boundaries = "side")
  expect_equal(setback_distance(p, c(2, 3, 6)), c(0, 0.5, 3.5))
  p60 <- plane(60, start_height = 4, boundaries = "side", set_in = 1)
  expect_equal(setback_distance(p60, 10), 1 + 6 / tan(pi / 3))
  # slope given as rise per run
  expect_equal(plane(slope = 1, start_height = 0, boundaries = "road")$angle_deg, 45)
})

test_that("graded and capped planes follow the boundary's bearing", {
  p <- plane(angle_by_orientation = c(north = 55, east = 39, south = 26, west = 39),
             start_height = 2.3, boundaries = "side")
  north <- setback_distance(p, 10, bearing = 0)
  east <- setback_distance(p, 10, bearing = 90)
  ne <- setback_distance(p, 10, bearing = 45)
  expect_equal(north, (10 - 2.3) / tan(55 * pi / 180))
  expect_equal(ne, (10 - 2.3) / tan(47 * pi / 180))
  expect_gt(east, north)
  v <- plane(45, 2, "side", vertical_above = 8)
  expect_equal(setback_distance(v, c(8, 20)), c(6, 6))
  cap <- plane(45, 2, "side", max_setback_above = c(height = 12, north = 6, east = 8, south = 8, west = 8))
  expect_equal(setback_distance(cap, c(10, 20), bearing = 0), c(8, 6))
})

test_that("proportional and profile setbacks", {
  expect_equal(setback_distance(proportional_setback(0.4, "side", min = 3), c(5, 10, 20)),
               c(3, 4, 8))
  pr <- setback_profile(height = c(0, 3.6, 6.9), distance = c(1, 1, 2), "side")
  expect_equal(setback_distance(pr, c(2, 5.25, 10)), c(1, 1.5, 2))
})

test_that("constructors reject bad input", {
  expect_error(yard(-1, "side"))
  expect_error(plane(start_height = 2, boundaries = "side"))
  expect_error(setback_profile(c(3, 1), c(1, 1), "side"))
  expect_error(yard(1, "side", when = list(min_site_area = 1)))
  expect_error(conditions(distance_to = "transit"))
})
