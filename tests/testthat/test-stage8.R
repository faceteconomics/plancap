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

test_that("Hamilton's rulebook covers the centres, business and industrial zones", {
  rb <- rulebook_example("hamilton")
  expect_true(all(c("LLRZ", "PMRZ", "B1", "B3", "B4", "B5", "B7", "PNCZ", "PLCZ", "CC1", "CC2", "CC3",
                    "KNZ", "IND", "RLZ", "RIPZ", "TRNZ") %in% names(rb$zones)))
  # The Central City's height is an assumption and says so.
  expect_match(rb$zones$CC1$height$source, "^Assumption")
  # Business 4 provides for no dwellings; Business 5 does, above ground floor.
  expect_identical(rb$zones$B4$use$residential, FALSE)
  expect_identical(rb$zones$B5$use$residential, TRUE)
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

# ---- Road classes from centre lines (Hamilton's arterial setback) -----------

class_lines <- function() {
  sf::st_sf(cls = c("Minor Arterial Road", "Local Road"),
            geometry = sf::st_sfc(sf::st_linestring(rbind(c(-200, -10), c(50, -10))),
                                  sf::st_linestring(rbind(c(50, -10), c(300, -10))), crs = NZTM))
}
class_rulebook <- function(field = "cls") {
  rb <- rulebook("Classes") |>
    add_zone(zone("A", height = height_limit(8, source = "h"),
                  setbacks = list(yard(1, "road", source = "y1"),
                                  yard(5, "minor_arterial_road", source = "y5"))),
             zone("B", height = height_limit(8, source = "h")),
             zone("OS", method = "none", source = "OS")) |>
    set_zone_families(OPEN_SPACE = "OS") |>
    set_conversion(conversion(dwelling_size = 100))
  rb$morphology$road_class_field <- field
  rb
}

test_that("road boundaries are tagged with the class of the road in front", {
  sc <- scenario("C", class_rulebook(), parcels = fixture_parcels(), roads = fixture_road(),
                 zoning = fixture_zoning(), centrelines = class_lines())
  seg <- prepare_sites(sc)$segments
  road <- seg[seg$boundary_class == "road", ]
  west <- road$site_id[grepl("minor_arterial_road", road$tags)]
  east <- road$site_id[grepl("local_road", road$tags)]
  expect_true(length(west) > 0 && length(east) > 0)
  expect_length(intersect(west, east), 0)
  # Without the field, nothing is tagged.
  sc0 <- scenario("C0", class_rulebook(""), parcels = fixture_parcels(), roads = fixture_road(),
                  zoning = fixture_zoning(), centrelines = class_lines())
  expect_false(any(grepl("arterial", prepare_sites(sc0)$segments$tags)))
})

test_that("a setback naming a road class applies only along that class", {
  rb <- class_rulebook()
  expect_true(validate_rulebook(rb)$valid)
  run <- function(rb) {
    cap <- estimate_capacity(scenario("C", rb, parcels = fixture_parcels(), roads = fixture_road(),
                                      zoning = fixture_zoning(), centrelines = class_lines()))
    s <- sf::st_drop_geometry(cap$sites)
    stats::setNames(s$footprint, s$parcel_id %||% s$site_id)
  }
  with_class <- run(rb)
  rb$morphology$road_class_field <- ""
  without <- run(rb)
  # Zone A sites (west of x = 40) front the arterial and lose a deeper front strip.
  expect_true(any(with_class < without - 1e-6))
  expect_true(all(with_class <= without + 1e-6))
})
