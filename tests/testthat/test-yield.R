# Yield on the fixture: P1 (and its neighbours) are 600 m2. Zone A is 8 m:
# two 3 m storeys of 600 m2 with no setbacks, so 1,200 m2 of floor area.

yield_rb <- function(...) {
  set_conversion(fixture_rulebook(), conversion(dwelling_size = 100, efficiency = 1, min_one_dwelling = TRUE,
                                                min_one_dwelling_floor = 40))
}
cap_of <- function(rb, parcels = fixture_parcels(), layers = list(), zoning = fixture_zoning(), ...) {
  estimate_capacity(scenario("Y", rb, parcels = parcels, roads = fixture_road(), zoning = zoning,
                             layers = layers), ...)
}
site <- function(cap, id) sf::st_drop_geometry(cap$sites)[cap$sites$site_id == id, ]

test_that("volumetric: residential floor area over dwelling size", {
  p1 <- site(cap_of(yield_rb()), "P1")
  expect_equal(p1$floor_area, 1200)
  expect_identical(p1$path, "volumetric")
  expect_identical(p1$dwellings, 12L)
  half <- cap_of(set_conversion(yield_rb(), conversion(dwelling_size = 100, efficiency = 0.5)))
  expect_identical(site(half, "P1")$dwellings, 6L)
})

test_that("a site with a little residential floor area still counts one dwelling", {
  rb <- set_conversion(yield_rb(), conversion(dwelling_size = 2000, min_one_dwelling_floor = 40))
  expect_identical(site(cap_of(rb), "P1")$dwellings, 1L)
  rb2 <- set_conversion(yield_rb(), conversion(dwelling_size = 2000, min_one_dwelling = FALSE))
  expect_identical(site(cap_of(rb2), "P1")$dwellings, 0L)
})

test_that("density: by land per dwelling, or the vacant-site minimum with at least one", {
  rb <- yield_rb() |> set_rule("zones.A.method", "density", validate = FALSE) |>
    set_rule("zones.A.density", list(site_area_per_dwelling = 200, source = "d"))
  expect_identical(site(cap_of(rb), "P1")$dwellings, 3L)
  rb2 <- set_rule(rb, "zones.A.density", list(vacant_site_min_area = 450, source = "d"))
  p1 <- site(cap_of(rb2), "P1")
  expect_identical(p1$dwellings, 1L)
  expect_identical(p1$dwelling_binding, "vacant_site_minimum")
})

test_that("hybrid takes the lesser of envelope and density", {
  rb <- yield_rb() |> set_rule("zones.A.method", "hybrid", validate = FALSE) |>
    set_rule("zones.A.density", list(site_area_per_dwelling = 300, source = "d"))
  p1 <- site(cap_of(rb), "P1")
  expect_identical(p1$dwellings, 2L)
  expect_identical(p1$path, "hybrid_density")
})

test_that("large sites count by the land less the deduction, by divisor", {
  rb <- yield_rb() |>
    set_defaults(large_site = list(threshold = 500, deduction = 0.25, method = "divisor")) |>
    set_rule("zones.A.density", list(large_site = list(area_per_dwelling = 100), source = "d"))
  p1 <- site(cap_of(rb), "P1")
  expect_identical(p1$path, "large_site")
  expect_identical(p1$dwellings, 4L)     # floor(600 * 0.75 / 100)
  env <- set_defaults(rb, large_site = list(threshold = 500, deduction = 0.25, method = "envelope"))
  p1e <- site(cap_of(env), "P1")
  expect_identical(p1e$path, "volumetric")
  expect_identical(p1e$dwellings, 9L)    # floor(12 * 0.75)
})

test_that("a floor area ratio caps the stack's total from the ground up", {
  rb <- set_rule(yield_rb(), "zones.A.ratios", list(far_max = list(value = 1.5, source = "f")))
  cap <- cap_of(rb)
  expect_equal(site(cap, "P1")$floor_area, 900)
  st <- cap$stack[cap$stack$site_id == "P1", ]
  expect_equal(st$enabled_area, c(600, 300))
  expect_identical(st$binding[2], "far")
})

test_that("residential share by storey splits floor area between uses", {
  rb <- set_rule(yield_rb(), "zones.A.use", list(residential = TRUE, business = TRUE,
    residential_share = list(bands = list(by = "storey", bands = list(list(min = 0, max = 1, value = 0),
                                                                      list(min = 1, value = 1))))))
  p1 <- site(cap_of(rb), "P1")
  expect_equal(c(p1$residential_floor_area, p1$business_floor_area), c(600, 600))
  expect_identical(p1$dwellings, 6L)
})

test_that("exclusions take land off, or keep dwellings off, as they say", {
  hz <- sf::st_sf(geometry = sf::st_sfc(rect(20, 15, 40, 30), crs = NZTM))
  rb_all <- add_overlay(yield_rb(), overlay("hz", "exclusion", layer = "hazard", source = "h"))
  p1 <- site(cap_of(rb_all, layers = list(hazard = hz)), "P1")
  expect_equal(p1$floor_area, 600)        # half the site, two storeys
  expect_equal(p1$removed_area, 300)
  rb_res <- add_overlay(yield_rb(), overlay("hz", "exclusion", layer = "hazard", removes = "residential",
                                            source = "h"))
  rb_res <- set_rule(rb_res, "zones.A.use", list(residential = TRUE, business = TRUE, residential_share = 1))
  p1r <- site(cap_of(rb_res, layers = list(hazard = hz)), "P1")
  expect_equal(p1r$floor_area, 1200)
  expect_equal(p1r$residential_floor_area, 600)
  expect_equal(p1r$business_floor_area, 600)
})

test_that("a density lot the overlays remove holds no dwelling", {
  hz <- sf::st_sf(geometry = sf::st_sfc(rect(19, -1, 41, 31), crs = NZTM))
  rb <- yield_rb() |> set_rule("zones.A.method", "density", validate = FALSE) |>
    set_rule("zones.A.density", list(vacant_site_min_area = 450, source = "d")) |>
    add_overlay(overlay("hz", "exclusion", layer = "hazard", source = "h"))
  p1 <- site(cap_of(rb, layers = list(hazard = hz)), "P1")
  expect_identical(p1$dwellings, 0L)
  expect_identical(p1$flag, "no_capacity")
})

test_that("access width, dwellings per site and area totals cap dwellings", {
  rb <- set_rule(yield_rb(), "zones.A.density", list(
    access_width = list(list(min = 0, max = 30, max_dwellings = 5)), source = "a"))
  p1 <- site(cap_of(rb), "P1")
  expect_identical(p1$dwellings, 5L)
  expect_identical(p1$dwelling_binding, "access_width")
  rb2 <- set_rule(yield_rb(), "zones.A.density", list(max_dwellings_per_site = 4, source = "m"))
  expect_identical(site(cap_of(rb2), "P1")$dwellings, 4L)
  rb3 <- add_area(yield_rb(), area("pre", "precincts", max_dwellings = 12, source = "p"))
  prec <- sf::st_sf(geometry = sf::st_sfc(rect(0, 0, 40, 30), crs = NZTM))
  cap <- cap_of(rb3, layers = list(precincts = prec))
  expect_identical(site(cap, "P7")$dwellings + site(cap, "P1")$dwellings, 12L)
})

test_that("entitlements raise to their floor, bonuses are reported apart", {
  rb <- set_conversion(yield_rb(), conversion(dwelling_size = 1000, min_one_dwelling = FALSE)) |>
    add_entitlement(entitlement("three", "dwellings", 3, applies_to_zones = "A", source = "law")) |>
    add_bonus(bonus("b", "dwellings", 2, combine = "add", applies_to_zones = "A", source = "b"))
  p1 <- site(cap_of(rb), "P1")
  expect_identical(p1$dwellings, 3L)
  expect_identical(p1$dwelling_binding, "entitlement")
  expect_identical(p1$dwellings_with_bonus, 5L)
  p2 <- site(cap_of(rb), "P2")
  expect_identical(p2$dwellings, 1L)       # zone B: 1,800 m2 / 1,000
  expect_identical(p2$dwellings_with_bonus, 1L)
})

test_that("every site is reported, and incremental capacity equals a full run", {
  sc <- scenario("Y", yield_rb(), parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
  base <- estimate_capacity(sc)
  expect_identical(nrow(base$sites), 6L)
  ch <- scenario_change(sc, "Y2", rulebook = set_rule(sc$rulebook, "zones.B.height.value", 14))
  inc <- estimate_capacity(ch, baseline = base)
  full <- estimate_capacity(ch)
  expect_identical(inc$envelope$report$copied_from_baseline, 3L)
  expect_equal(sf::st_drop_geometry(inc$sites), sf::st_drop_geometry(full$sites), ignore_attr = TRUE)
})

test_that("Exampleton's capacity adds up", {
  town <- exampleton()
  p <- town$parcels
  cap <- estimate_capacity(scenario("Operative", rulebook_example("exampleton"),
    parcels = p[p$parcel_type == "land", ], roads = p[p$parcel_type == "road", ], zoning = town$zoning,
    layers = town[c("height_areas", "flood_hazard", "heritage", "trees", "precincts", "transit")],
    water = town$water))
  s <- sf::st_drop_geometry(cap$sites)
  expect_equal(sum(s$floor_area), sum(s$residential_floor_area) + sum(s$business_floor_area), tolerance = 1e-9)
  expect_true(all(s$business_floor_area[s$zone_key %in% c("LDR", "MDR", "HDR")] == 0))
  expect_true(all(s$residential_floor_area[s$zone_key == "IND"] == 0))
  expect_true(all(s$dwellings[s$zone_key == "TC"] > 0))
  expect_gt(sum(s$dwellings_with_bonus), sum(s$dwellings))
  msgs <- capture.output(print(cap), type = "message")
  expect_true(any(grepl("plancap capacity", msgs)))
})
