full_rulebook <- function() {
  rulebook("Test Plan", id = "test", country = "NZ") |>
    add_zone(zone("MDR", "Medium Density Residential",
      height = height_limit(12, roof_allowance = 1, storeys = 3, source = "S1"),
      setbacks = list(
        yard(1.5, "road", source = "S4"),
        plane(60, 4, c("side", "rear"), source = "S3",
              when = conditions(not_adjacent_zones = "OS", min_site_area = 300)),
        plane(angle_by_orientation = c(north = 55, east = 45, south = 35, west = 45),
              start_height = 2.5, boundaries = "side", source = "T"),
        setback_profile(c(0, 3.6, 6.9), c(1, 1, 2), "side", source = "B17"),
        proportional_setback(0.4, "rear", min = 3, variant = "alt", source = "P"),
        yard("max(3, 0.4 * H)", "rear", from_storey = 2, source = "F")),
      coverage = ratio(bands("site_area", c(200, Inf), list(0.55, "max(0.4, 0.5)")), source = "T1"),
      landscaping = ratio(0.2, source = "S6"),
      form = building_form(max_building_length = 20,
                           building_separation = bands("height", c(12, Inf), c(6, 9)),
                           site_shape = c(8, 15), source = "F"),
      density = density(min_site_area = 200,
                        access_width = data.frame(min = c(0, 3.5), max = c(3.5, NA),
                                                  max_dwellings = c(3, NA)), source = "D"),
      use = use_mix(TRUE, TRUE, residential_share = bands("storey", c(1, Inf), c(0, 1)),
                    source = "U"),
      variants = list(standard = list(label = "Standard"), alt = list(label = "Alt"))),
      codes = c("MDR", "MRZ")) |>
    add_zone(zone("OS", "Open Space", method = "none", source = "OS")) |>
    add_overlay(
      overlay("hc", "height", layer = "height_areas", value_field = "max_height_m",
              combine = "replace", filter = list(status = "Operative"), source = "maps"),
      overlay("char", "parameters", layer = "char", applies_to_zones = "MDR",
              parameters = zone_changes(setbacks = list(yard(3, "road", source = "c"))),
              additions = zone_changes(setbacks = list(yard(10, "riparian", source = "r"))),
              source = "x")) |>
    add_area(area("quarry", "precincts", sub_area_field = "sub_precinct",
      parameters = zone_changes(height = height_limit(16, source = "a")),
      sub_areas = list(
        B = zone_changes(height = height_limit(20, source = "b")),
        C = sub_area(zone_changes(replaces_setbacks = "plane"),
                     zone_parameters = list(MDR = zone_changes(density = density(min_site_area = 450, source = "e"))),
                     max_dwellings = 50, total_group = "BC")),
      max_dwellings = 200, source = "Q")) |>
    add_bonus(bonus("aff", "far", 0.5, applies_to_zones = "MDR", source = "B")) |>
    add_entitlement(entitlement("three", "dwellings", 3, applies_to_zones = "MDR", source = "E")) |>
    add_unmodelled(unmodelled_rule("Outlook", "windows", zones = "MDR", size = "small")) |>
    set_zone_families(OPEN_SPACE = "OS") |>
    set_morphology(corner_angle_tolerance = 25, reserve_families = "OPEN_SPACE") |>
    set_conversion(conversion(dwelling_size = 90, efficiency = 0.85, source = "C")) |>
    set_ground("with_access", parking_area_per_dwelling = 25)
}

test_that("a rulebook built in R validates cleanly", {
  rb <- full_rulebook()
  expect_s3_class(rb, "plancap_rulebook")
  v <- validate_rulebook(rb)
  expect_true(v$valid)
  expect_equal(nrow(v$issues), 0)
  expect_output(print(rb), "Medium Density Residential")
})

test_that("YAML, JSON and XLSX round trips are lossless", {
  rb <- full_rulebook()
  for (ext in c("yaml", "json", "xlsx")) {
    if (ext == "xlsx") skip_if_not_installed("openxlsx2")
    f <- withr::local_tempfile(fileext = paste0(".", ext))
    write_rulebook(rb, f)
    expect_identical(to_plain(read_rulebook(f)), to_plain(rb), info = ext)
  }
})

test_that("metres to feet and back is lossless, formulas included", {
  rb <- full_rulebook()
  ft <- convert_rulebook_units(rb, "ft")
  expect_equal(ft$zones$MDR$height$value, 12 / 0.3048)
  back <- convert_rulebook_units(ft, "m")
  expect_equal(back$zones$MDR$setbacks[[2]]$start_height, 4)
  f_m <- rb$zones$MDR$setbacks[[6]]$distance
  f_b <- back$zones$MDR$setbacks[[6]]$distance
  expect_equal(eval_rule_value(f_b, list(H = c(5, 20))), eval_rule_value(f_m, list(H = c(5, 20))))
  expect_equal(back$zones$MDR$ratios$coverage_max$bands$bands[[1]]$max, 200)
})

test_that("validation catches typos, bad references and missing sources", {
  x <- to_plain(full_rulebook())
  x$zones$MDR$hieght <- 3
  x$zones$MDR$setbacks[[1]]$kind <- "yrad"
  x$zone_map$XYZ <- "NOPE"
  x$zones$MDR$setbacks[[2]]$when$adjacent_zones <- "MARS"
  v <- validate_rulebook(normalise_rulebook(x))
  expect_false(v$valid)
  expect_true(any(grepl("hieght", v$issues$message)))
  expect_true(any(grepl("allowed values", v$issues$message)))
  expect_true(any(grepl("unknown zone 'NOPE'", v$issues$message)))
  expect_true(any(grepl("MARS", v$issues$message)))
  f <- withr::local_tempfile(fileext = ".yaml")
  writeLines(yaml::as.yaml(x), f)
  expect_error(read_rulebook(f), "error")

  rb <- rulebook("X") |> add_zone(zone("A", height = height_limit(8)))
  w <- validate_rulebook(rb)$issues
  expect_true(any(w$severity == "warning" & grepl("citation|source", w$message)))
})

test_that("extends, set_rule and extend_rulebook change rules", {
  rb <- full_rulebook()
  base <- withr::local_tempfile(fileext = ".yaml")
  write_rulebook(rb, base)
  child <- withr::local_tempfile(fileext = ".yaml")
  writeLines(c(paste0("extends: ", base),
               "zones:",
               "  MDR:",
               "    height: {value: 16, source: 'PC1'}",
               "    notes: ~"), child)
  rb2 <- read_rulebook(child)
  # Named entries merge: the new value replaces, the rest of `height` stays;
  # `~` removes an entry.
  expect_equal(rb2$zones$MDR$height$value, 16)
  expect_equal(rb2$zones$MDR$height$occupiable, 11)
  expect_null(rb2$zones$MDR$notes)
  expect_length(rb2$zones$MDR$setbacks, 6)

  rb3 <- set_rule(rb, "zones.MDR.setbacks[2].start_height", 6)
  expect_equal(rb3$zones$MDR$setbacks[[2]]$start_height, 6)
  expect_error(set_rule(rb, "zones.MDR.setbacks[2].kind", "nope"), "error")
  rb4 <- extend_rulebook(rb, list(zones = list(MDR = list(ratios = list(far_max = list(value = 2, source = "x"))))))
  expect_equal(rb4$zones$MDR$ratios$far_max$value, 2)
  expect_equal(rb4$zones$MDR$ratios$coverage_max, rb$zones$MDR$ratios$coverage_max)
})

test_that("rule_table lists every rule with its source", {
  rt <- rule_table(full_rulebook())
  expect_s3_class(rt, "data.frame")
  expect_true(all(c("zone", "overlay", "area", "bonus", "entitlement", "unmodelled") %in% rt$scope))
  expect_true("setback:plane" %in% rt$rule)
  expect_true(any(grepl("by site_area", rt$value)))
})

test_that("bands look up values, closed on the right", {
  b <- bands("site_area", c(200, 300, Inf), c(0.55, 0.45, 0.35))
  expect_equal(band_value(b, c(150, 200, 250, 1000)), c(0.55, 0.55, 0.45, 0.35))
  expect_error(bands("site_area", c(300, 200), c(1, 2)))
})

test_that("the XLSX template reads back as a valid rulebook", {
  skip_if_not_installed("openxlsx2")
  f <- withr::local_tempfile(fileext = ".xlsx")
  rulebook_template(f)
  rb <- read_rulebook(f)
  expect_true(validate_rulebook(rb)$valid)
  expect_named(rb$zones, "ZONE1")
})
