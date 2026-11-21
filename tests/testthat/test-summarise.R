# Summaries on the fixture. Six 600 m2 lots: P7, P1 and P6 in zone A (8 m,
# two storeys), P2, P4 and P5 in zone B (11 m, three storeys); no setbacks,
# so every storey is the whole lot.

sum_rb <- function() set_conversion(fixture_rulebook(), conversion(dwelling_size = 100))
sum_cap <- function(rb = sum_rb()) {
  estimate_capacity(scenario("S", rb, parcels = fixture_parcels(), roads = fixture_road(),
                             zoning = fixture_zoning()))
}

test_that("groups add up to the total and land reconciles", {
  cap <- sum_cap()
  z <- summarise_capacity(cap, by = "zone")
  expect_s3_class(z, "plancap_summary")
  expect_identical(z$zone_key, c("A", "B"))
  expect_identical(as.integer(z$sites), c(3L, 3L))
  expect_equal(z$floor_area, c(3 * 1200, 3 * 1800))
  expect_equal(sum(z$land_area), 3600)
  expect_equal(sum(z$floor_area_share), 1)
  expect_equal(z$far, c(2, 3))
  tot <- summarise_capacity(cap, by = NULL, measures = c("sites", "floor_area", "dwellings"))
  expect_equal(tot$floor_area, 9000)
  expect_equal(tot$dwellings, sum(cap$sites$dwellings))
  expect_error(summarise_capacity(cap, measures = "volume"), "Unknown measure")
  expect_error(summarise_capacity(cap, by = "colour"), "Cannot group")
})

test_that("bands, storeys and floor area by storey level", {
  cap <- sum_cap()
  hb <- summarise_capacity(cap, by = "height_band", measures = "sites")
  expect_identical(as.character(hb$height_band), c("0-9 m", "9-12 m"))
  st <- summarise_capacity(cap, by = "storey")
  expect_identical(as.integer(st$storey), 1:3)
  expect_equal(st$floor_area, c(3600, 3600, 1800))
  expect_equal(sum(st$floor_area), sum(cap$sites$floor_area))
  sz <- summarise_capacity(cap, by = "site_size_band", measures = "sites", breaks = list(site_size = c(0, 500, Inf)))
  expect_identical(as.character(sz$site_size_band), "500 m2+")
})

test_that("sites go to the area covering most of them, and to grid cells", {
  cap <- sum_cap()
  areas <- sf::st_sf(name = c("West", "East"), geometry = sf::st_sfc(rect(-10, -5, 45, 80), rect(45, -5, 120, 80),
                                                                     crs = NZTM))
  a <- summarise_capacity(cap, by = "area", areas = areas, area_id = "name", measures = c("sites", "floor_area"))
  expect_s3_class(a, "sf")
  # P2 (x 40-60) is three quarters in East.
  expect_identical(a$area, c("East", "West"))
  expect_identical(as.integer(a$sites), c(3L, 3L))
  g <- summarise_capacity(cap, by = "grid", grid = 50, measures = "sites")
  expect_equal(sum(g$sites), 6)
  expect_s3_class(g, "sf")
})

test_that("the constraint breakdown runs from the theoretical maximum to the enabled floor area", {
  rb <- sum_rb() |>
    set_rule("zones.A.ratios", list(coverage_max = list(value = 0.5, source = "c"))) |>
    set_rule("zones.B.ratios", list(far_max = list(value = 2, source = "f")))
  cap <- sum_cap(rb)
  b <- constraint_breakdown(cap)
  expect_s3_class(b, "plancap_breakdown")
  expect_equal(b$floor_area[b$step == "theoretical"], 3 * 600 * 2 + 3 * 600 * 3)
  expect_equal(b$floor_area[b$step == "coverage"], 3 * 2 * 300)
  expect_equal(b$floor_area[b$step == "far"], 3 * (1800 - 1200))
  expect_equal(b$floor_area[b$step == "enabled"], sum(cap$sites$floor_area))
  steps <- b[!b$step %in% c("theoretical", "enabled"), ]
  expect_equal(b$floor_area[1] - sum(steps$floor_area), sum(cap$sites$floor_area))
  bz <- constraint_breakdown(cap, by = "zone")
  expect_identical(unique(bz$zone_key), c("A", "B"))
})

test_that("check_capacity reconciles a clean run", {
  ch <- check_capacity(sum_cap())
  expect_s3_class(ch, "plancap_checks")
  expect_false(any(ch$status == "fail"))
  expect_identical(ch$status[ch$check == "parcels accounted for"], "ok")
  expect_identical(ch$status[ch$check == "land in equals land out"], "ok")
})

test_that("explain_site shows the boundaries, setbacks and storeys", {
  rb <- set_rule(sum_rb(), "zones.A.setbacks",
                 list(list(kind = "yard", distance = 3, boundaries = list("road"), source = "front yard")),
                 validate = FALSE)
  cap <- sum_cap(rb)
  ex <- explain_site(cap, "P1")
  expect_s3_class(ex, "plancap_explanation")
  expect_identical(nrow(ex$boundaries), 4L)
  front <- ex$setbacks[ex$setbacks$boundary_class == "road", ]
  expect_equal(front$setback, c(3, 3))
  expect_identical(unique(front$source), "front yard")
  expect_equal(ex$storeys$enabled_area, c(20 * 27, 20 * 27))
  expect_identical(ex$rules$kind[1], "zone")
  expect_error(explain_site(cap, "nope"), "No site")
  expect_output(print(ex), "storey")
})

test_that("sensitivity sweeps a rule, incrementally", {
  rb <- set_rule(sum_rb(), "zones.A.ratios", list(coverage_max = list(value = 0.5, source = "c")))
  sc <- scenario("S", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
  s <- sensitivity(sc, "zones.A.ratios.coverage_max.value", c(0.4, 0.5), by = "zone")
  expect_s3_class(s, "plancap_sensitivity")
  a <- s[s$zone_key == "A", ]
  expect_equal(a$floor_area, c(3 * 2 * 240, 3 * 2 * 300))
  expect_equal(a$floor_area_change, c(0, 360))
  expect_equal(s$floor_area_change[s$zone_key == "B"], c(0, 0))
})

test_that("the unmodelled register and the formatted table", {
  u <- unmodelled_report(rulebook_example("exampleton"))
  expect_true(nrow(u) > 0)
  expect_named(u, c("rule", "reason", "zones", "likely_effect", "size", "source"))
  expect_identical(nrow(unmodelled_report(sum_rb())), 0L)
  skip_if_not_installed("gt")
  expect_s3_class(capacity_table(sum_cap()), "gt_tbl")
})

test_that("summary() gives the headline and capacity by zone", {
  sm <- summary(sum_cap())
  expect_s3_class(sm, "plancap_capacity_summary")
  expect_equal(sm$headline$floor_area, 9000)
  expect_output(print(sm), "A")
})
