# Scenario comparison on the fixture: six 600 m2 lots, zone A (8 m, two
# storeys) west of x = 40, zone B (11 m, three storeys) east of it.

cmp_rb <- function() set_conversion(fixture_rulebook(), conversion(dwelling_size = 100))
cmp_base <- function() {
  scenario("Base", cmp_rb(), parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
}
fa <- function(cap) sum(cap$sites$floor_area)
cmp_cap_of <- function(sc, ids) {
  cap <- estimate_capacity(sc)
  cap$sites <- cap$sites[cap$sites$site_id %in% ids, ]
  cap
}

test_that("a scenario set runs incrementally and equals full runs", {
  base <- cmp_base()
  taller <- scenario_change(base, "Taller B", rulebook = set_rule(cmp_rb(), "zones.B.height",
                                                                   list(value = 14, storeys = 4, source = "h")))
  set <- scenario_set(base, taller)
  expect_s3_class(set, "plancap_scenario_set")
  expect_error(scenario_set(base, base), "differ")
  res <- run_scenarios(set, progress = FALSE)
  expect_identical(names(res), c("Base", "Taller B"))
  expect_equal(fa(res[["Taller B"]]), fa(estimate_capacity(taller)))
  expect_gt(res[["Taller B"]]$report$envelope$copied_from_baseline, 0)
})

test_that("a rule change is attributed to the rules, site by site", {
  base <- cmp_base()
  taller <- scenario_change(base, "Taller B", rulebook = set_rule(cmp_rb(), "zones.B.height",
                                                                   list(value = 14, storeys = 4, source = "h")))
  cmp <- compare_scenarios(run_scenarios(scenario_set(base, taller), progress = FALSE))
  p <- cmp$pairs[[1]]
  expect_equal(p$totals$change[p$totals$measure == "floor_area"], 3 * 600)
  expect_identical(p$attribution$driver, "rules")
  expect_equal(p$attribution$floor_area, 3 * 600)
  expect_identical(p$rule_attribution$rule, "zones.B")
  s <- sf::st_drop_geometry(p$sites)
  expect_setequal(s$unit[s$reason == "rule_changed"], c("P2", "P4", "P5"))
  expect_setequal(s$unit[s$reason == "unchanged"], c("P7", "P1", "P6"))
  expect_false(any(check_comparison(cmp)$status == "fail"))
  d <- p$inputs
  expect_identical(d$fields, "rulebook")
  expect_identical(d$rules$change, "changed")
})

test_that("rezoning shows as a zone transition and as rezoned sites", {
  base <- cmp_base()
  rez <- scenario_change(base, "Rezoned", zoning = fixture_zoning(split = 60))
  cmp <- compare_scenarios(run_scenarios(scenario_set(base, rez), progress = FALSE))
  p <- cmp$pairs[[1]]
  s <- sf::st_drop_geometry(p$sites)
  expect_identical(s$reason[s$unit == "P2"], "rezoned")
  expect_equal(s$floor_area_change[s$unit == "P2"], 1200 - 1800)
  tr <- p$transitions
  b2a <- tr[tr$from == "B" & tr$to == "A", ]
  expect_equal(b2a$land_area, 600)
  expect_equal(b2a$floor_area_change, -600)
  expect_identical(p$attribution$driver, "zoning")
  rz <- p$inputs$rezoned
  expect_equal(sum(rz$area), 20 * 170)
  expect_false(any(check_comparison(cmp)$status == "fail"))
})

test_that("changed parcels are apportioned to the baseline's, and every total reconciles", {
  base <- cmp_base()
  p <- fixture_parcels()
  split <- sf::st_sf(parcel_id = c("P1a", "P1b"), title_id = NA,
                     geometry = sf::st_sfc(rect(20, 0, 30, 30), rect(30, 0, 40, 30), crs = NZTM))
  p2 <- rbind(p[p$parcel_id != "P1", ], split)
  sub <- scenario_change(base, "Subdivided", parcels = p2)
  cmp <- compare_scenarios(run_scenarios(scenario_set(base, sub), progress = FALSE))
  pr <- cmp$pairs[[1]]
  s <- sf::st_drop_geometry(pr$sites)
  expect_identical(s$reason[s$unit == "P1"], "parcel_changed")
  expect_equal(s$floor_area_scenario[s$unit == "P1"], fa(cmp_cap_of(sub, c("P1a", "P1b"))))
  expect_identical(pr$attribution$driver, "parcels")
  expect_equal(pr$land$area[3:4], c(0, 0))
  expect_false(any(check_comparison(cmp)$status == "fail"))
  expect_identical(sort(pr$inputs$parcels$id), c("P1", "P1a", "P1b"))
})

test_that("several drivers sum to the change, sequentially and by Shapley", {
  base <- cmp_base()
  both <- scenario_change(base, "Both", zoning = fixture_zoning(split = 60),
                          rulebook = set_rule(cmp_rb(), "zones.A.height", list(value = 11, storeys = 3, source = "h")))
  res <- run_scenarios(scenario_set(base, both), progress = FALSE)
  total <- fa(res[["Both"]]) - fa(res[["Base"]])
  seq <- compare_scenarios(res)$pairs[[1]]$attribution
  expect_identical(seq$driver, c("rules", "zoning"))
  expect_equal(sum(seq$floor_area), total)
  sh <- compare_scenarios(res, attribution = "shapley")$pairs[[1]]$attribution
  expect_equal(sum(sh$floor_area), total)
  # Order matters sequentially; Shapley averages the two orders.
  rev <- compare_scenarios(res, order = c("zoning", "rules"))$pairs[[1]]$attribution
  expect_equal(sh$floor_area[sh$driver == "rules"],
               mean(c(seq$floor_area[seq$driver == "rules"], rev$floor_area[rev$driver == "rules"])))
})

test_that("a common geography reconciles", {
  base <- cmp_base()
  rez <- scenario_change(base, "Rezoned", zoning = fixture_zoning(split = 60))
  areas <- sf::st_sf(name = c("West", "East"), geometry = sf::st_sfc(rect(-10, -5, 50, 80), rect(50, -5, 120, 80),
                                                                     crs = NZTM))
  cmp <- compare_scenarios(run_scenarios(scenario_set(base, rez), progress = FALSE), areas = areas,
                           area_id = "name", grid = 50, attribution = "none")
  a <- cmp$pairs[[1]]$by_area
  expect_s3_class(a, "sf")
  expect_equal(sum(a$floor_area_change), -600)
  expect_null(cmp$pairs[[1]]$attribution)
  expect_false(any(check_comparison(cmp)$status == "fail"))
})

test_that("Exampleton PC1 and its manifest", {
  skip_on_cran()
  pc1 <- exampleton_pc1()
  expect_s3_class(pc1$rulebook, "plancap_rulebook")
  expect_true("THZ" %in% pc1$zoning$zone)
  expect_true(any(startsWith(pc1$parcels$parcel_id, "N")))
  set <- read_scenarios(system.file("extdata", "exampleton_pc1_scenarios.yaml", package = "plancap"))
  expect_identical(names(set), c("Operative", "PC1 as notified"))
  expect_setequal(diff_fields(set[[1]], set[[2]]), c("rulebook", "parcels", "zoning", "layers"))
  # The stage 6 gate: an incremental run equals a full run.
  base <- estimate_capacity(set[[1]])
  inc <- estimate_capacity(set[[2]], baseline = base)
  full <- estimate_capacity(set[[2]])
  expect_gt(inc$report$envelope$copied_from_baseline, 0)
  expect_equal(inc$sites$floor_area, full$sites$floor_area)
  expect_equal(inc$sites$dwellings, full$sites$dwellings)
})
