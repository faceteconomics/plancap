test_that("every Exampleton layer loads, projected, in NZTM", {
  town <- exampleton()
  expect_named(town, exampleton_layers())
  for (nm in names(town)) {
    expect_s3_class(town[[nm]], "sf")
    expect_gt(nrow(town[[nm]]), 0)
    expect_equal(sf::st_crs(town[[nm]])$epsg, 2193L, info = nm)
  }
})

test_that("exampleton_layer() rejects unknown layers", {
  expect_error(exampleton_layer("nope"))
  expect_s3_class(exampleton_layer("zoning"), "sf")
})

test_that("parcels are valid and tile the town with no gaps or overlaps", {
  p <- exampleton_layer("parcels")
  expect_true(all(sf::st_is_valid(p)))
  expect_false(anyDuplicated(p$parcel_id) > 0)
  bb <- sf::st_bbox(p)
  total <- as.numeric((bb$xmax - bb$xmin) * (bb$ymax - bb$ymin))
  expect_equal(sum(as.numeric(sf::st_area(p))), total, tolerance = 1e-9)
  expect_equal(sum(lengths(sf::st_overlaps(p))), 0)
})

test_that("the cadastre has the lot forms the rules need", {
  p <- exampleton_layer("parcels")
  expect_setequal(unique(p$parcel_type), c("land", "road", "reserve"))
  forms <- table(p$lot_form)
  for (f in c("front", "rear", "through")) expect_gt(forms[[f]], 0)
  expect_gt(sum(duplicated(p$title_id)), 0)       # shared titles
  large <- p$parcel_type == "land" & as.numeric(sf::st_area(p)) >= 2500
  expect_true(any(large))
})

test_that("every land parcel is zoned, and some straddle a zone boundary", {
  p <- exampleton_layer("parcels")
  z <- exampleton_layer("zoning")
  land <- p[p$parcel_type == "land", ]
  hits <- sf::st_intersects(land, z)
  expect_true(all(lengths(hits) >= 1))
  overlap <- suppressWarnings(sf::st_intersection(land, z))
  overlap <- overlap[as.numeric(sf::st_area(overlap)) > 1, ]
  expect_true(any(duplicated(overlap$parcel_id)))
  expect_setequal(z$zone, c("TC", "MU", "HDR", "MDR", "LDR", "IND", "OS"))
})

test_that("the ground surface covers the town and includes steep ground", {
  skip_if_not_installed("terra")
  dem <- exampleton_dem()
  expect_s4_class(dem, "SpatRaster")
  slope <- terra::terrain(dem, "slope", unit = "degrees")
  steepest_pct <- tan(max(terra::values(slope), na.rm = TRUE) * pi / 180) * 100
  expect_gt(steepest_pct, 15)
})
