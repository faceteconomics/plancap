# The Excel template, the Hamilton rulebook entered through it, the 3D view.

test_that("a blank template has every column, families included", {
  skip_if_not_installed("openxlsx2")
  f <- withr::local_tempfile(fileext = ".xlsx")
  rulebook_template(f)
  expect_identical(names(openxlsx2::read_xlsx(f, sheet = "families"))[1], "family")
})

test_that("Hamilton's rulebook, entered through the template, matches its YAML copy", {
  skip_if_not_installed("openxlsx2")
  x <- system.file("extdata", "hamilton_rulebook.xlsx", package = "plancap")
  expect_true(nzchar(x))
  from_xlsx <- read_rulebook(x)
  from_yaml <- rulebook_example("hamilton")
  expect_true(validate_rulebook(from_xlsx)$valid)
  expect_identical(names(from_xlsx$zones), names(from_yaml$zones))
  expect_equal(from_xlsx$zones$MRZ, from_yaml$zones$MRZ)
  expect_identical(from_yaml$zones$MRZ$height$value, 18)
  # Every setback cites a rule.
  srcs <- unlist(lapply(from_yaml$zones, function(z) vapply(z$setbacks %||% list(), function(s) s$source %||% NA_character_, "")))
  expect_false(anyNA(srcs))
  expect_true(length(from_yaml$unmodelled_rules) >= 5)
})

test_that("the 3D view builds", {
  skip_if_not_installed("mapgl")
  cap <- estimate_capacity(scenario("3D", set_conversion(fixture_rulebook(), conversion(dwelling_size = 100)),
                                    parcels = fixture_parcels(), roads = fixture_road(),
                                    zoning = fixture_zoning()))
  m <- view_capacity_3d(cap)
  expect_s3_class(m, "htmlwidget")
  expect_s3_class(view_capacity_3d(cap, footprints = TRUE), "htmlwidget")
  expect_identical(basemap_credit(TRUE), "Basemap: Esri, World Gray Canvas.")
})
