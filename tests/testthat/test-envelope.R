# The storey stack, on capacityengine's fixture lot, with the Auckland rulebook
# converted from capacityengine: if the conversion and the engine are both
# right, the hand-worked figures of capacityengine's own tests come out.
#
# P1 is 20 m by 30 m (x 20-40, y 0-30), 600 m2, fronting the road at y = 0.

auckland_env <- function(code, variant = "standard", ...) {
  z <- sf::st_sf(zone = code, geometry = sf::st_sfc(rect(-200, -100, 300, 300), crs = NZTM))
  sc <- scenario("AKL fixture", rulebook_example("auckland"), parcels = fixture_parcels(),
                 roads = fixture_road(), zoning = z)
  suppressWarnings(build_envelopes(sc, variant_choice = variant, ...))
}
p1 <- function(e) e$stack[e$stack$site_id == "P1", , drop = FALSE]

test_that("MHS: clipped by the deeper of yard and plane, capped by coverage of site area", {
  e <- auckland_env("18")
  s <- p1(e)
  # MHS is 8 m in two storeys, so 4 m each, tested at the ceiling.
  expect_equal(s$ceiling_level, c(4, 8))
  # Storey 1 at 4 m: the plane (4 - 2.5) / tan 45 = 1.5 m beats the 1 m side
  # and rear yards; the road boundary takes the 3 m front yard. 17 by 25.5 m.
  expect_equal(s$clipped_area, c(17 * 25.5, 9 * 21.5))
  # 40% coverage of the 600 m2 SITE is 240 m2, whatever the envelope allows.
  expect_equal(s$enabled_area, c(240, 193.5))
  expect_identical(s$binding, c("coverage", "geometry"))
})

test_that("THAB: the stack ends where a storey falls below the floorplate", {
  e <- auckland_env("8")
  s <- p1(e)
  # 16 m in five storeys (3.2 m), 45 degrees from 3 m, yards 1.5 front, 1 other.
  expect_equal(s$clipped_area, c(18 * 27.5, 13.2 * 25.1, 6.8 * 21.9))
  # The fourth storey would be a 0.4 by 18.7 m strip: not a floorplate.
  expect_identical(nrow(s), 3L)
  expect_equal(s$enabled_area, c(300, 300, 148.92))
  expect_equal(e$sites$floor_area[e$sites$site_id == "P1"], 748.92)
})

test_that("no storey may exceed the smallest below it, and small storeys end the stack", {
  st <- data.frame(run = 1L, storey = 1:4, enabled_area = c(300, 100, 250, 20),
                   binding = "geometry", stringsAsFactors = FALSE)
  out <- stack_rules(st, 30)
  expect_equal(out$enabled_area, c(300, 100, 100))
  expect_identical(out$binding, c("geometry", "geometry", "stack_monotonic"))
})

test_that("setbacks can be kept, and they name the rule and citation that won", {
  e <- auckland_env("18", keep_setbacks = TRUE)
  sb <- e$setbacks[e$setbacks$site_id == "P1" & e$setbacks$storey == 1, ]
  expect_equal(sort(sb$setback), sort(c(3, 1.5, 1.5, 1.5)))
  expect_true(all(sb$rule[sb$setback == 1.5] == "plane"))
  expect_true(all(!is.na(sb$source[sb$setback > 0])))
  # Keeping them does not change the stack.
  expect_equal(p1(e)$enabled_area, p1(auckland_env("18"))$enabled_area)
})

# ---- Reflex corners ---------------------------------------------------------

yard_everywhere <- function(coords, d) {
  rb <- rulebook("Wedges") |>
    add_zone(zone("Z", height = height_limit(3, source = "h"),
                  setbacks = list(yard(d, c("road", "side", "rear"), source = "y"))))
  site <- sf::st_sf(parcel_id = "L", geometry = sf::st_sfc(sf::st_polygon(list(rbind(coords, coords[1, ]))), crs = NZTM))
  z <- sf::st_sf(zone = "Z", geometry = sf::st_sfc(rect(-100, -100, 100, 100), crs = NZTM))
  rb <- set_defaults(rb, min_floorplate = 1)
  env <- build_envelopes(scenario("W", rb, parcels = site, zoning = z), keep_geometry = TRUE)
  list(fp = geos::as_geos_geometry(env$geometry$geometry[1]),
       ring = geos::geos_boundary(geos::as_geos_geometry(sf::st_geometry(site))))
}

test_that("an L-shaped lot's inside corner is held back like every other edge", {
  L <- rbind(c(0, 0), c(20, 0), c(20, 10), c(10, 10), c(10, 20), c(0, 20))
  k <- yard_everywhere(L, 2)
  expect_gt(geos::geos_distance(k$fp, k$ring), 2 - 1e-6)
})

test_that("a frontage curving round a cul-de-sac head grows no fins", {
  th <- seq(pi, 2 * pi, length.out = 13)
  arc <- cbind(15 + 15 * cos(th), 6 - 6 * sin(th))
  k <- yard_everywhere(rbind(arc, c(30, 30), c(0, 30)), 2.5)
  expect_gt(geos::geos_distance(k$fp, k$ring), 2.5 - 1e-6)
  expect_identical(geos::geos_num_geometries(k$fp), 1L)
})

test_that("a convex lot is unchanged by the corner fill", {
  k <- yard_everywhere(rbind(c(0, 0), c(20, 0), c(20, 20), c(0, 20)), 3)
  expect_equal(geos::geos_area(k$fp), 14 * 14)
})

# ---- Rules, variants, conditions ----------------------------------------------

two_variant_rb <- function() {
  fixture_rulebook() |>
    set_rule("zones.A.setbacks", list(
      list(kind = "plane", angle_deg = 45, start_height = 2.5, boundaries = list("side", "rear"),
           variant = "strict", source = "a"),
      list(kind = "yard", distance = 1, boundaries = list("side", "rear"), variant = "loose", source = "b")),
      validate = FALSE)
}

test_that("each site takes the most enabling variant, or the one named", {
  sc <- scenario("V", two_variant_rb(), parcels = fixture_parcels(), roads = fixture_road(),
                 zoning = fixture_zoning())
  e <- build_envelopes(sc)
  expect_identical(e$sites$variant[e$sites$site_id == "P1"], "loose")
  expect_setequal(e$variants$variant[e$variants$site_id == "P1"], c("strict", "loose"))
  strict <- build_envelopes(sc, variant_choice = "strict")
  expect_identical(strict$sites$variant[strict$sites$site_id == "P1"], "strict")
  expect_lt(strict$sites$floor_area[strict$sites$site_id == "P1"],
            e$sites$floor_area[e$sites$site_id == "P1"])
})

test_that("an exemption that cannot be evaluated bites, and is reported", {
  rb <- fixture_rulebook() |>
    set_rule("zones.A.setbacks", list(list(kind = "yard", distance = 2, boundaries = list("road"),
                                           when = list(not_adjacent_zones = list("B")), source = "x")),
             validate = FALSE)
  z <- sf::st_sf(zone = "A", geometry = sf::st_sfc(rect(-200, -10, 300, 300), crs = NZTM))
  e <- build_envelopes(scenario("U", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = z))
  # Across the 20 m road is unzoned: the exemption cannot be shown, so the yard applies.
  expect_equal(p1(e)$clipped_area[1], 20 * 28)
  expect_true("not_adjacent_zones" %in% names(e$report$unevaluated))
})

test_that("a plane graded by orientation takes each boundary's own angle", {
  rb <- fixture_rulebook() |>
    set_rule("zones.A.setbacks", list(list(kind = "plane", angle_by_orientation = list(north = 55, east = 45, south = 35, west = 45),
                                           angle_deg = 35, start_height = 2, boundaries = list("side", "rear"), source = "g")),
             validate = FALSE)
  e <- build_envelopes(scenario("G", rb, parcels = fixture_parcels(), roads = fixture_road(),
                                zoning = fixture_zoning()), keep_setbacks = TRUE)
  sb <- e$setbacks[e$setbacks$site_id == "P1" & e$setbacks$storey == 1, ]
  # Zone A is 8 m in two 4 m storeys (capacityengine's storey height rule).
  # At 4 m: the rear (facing north) needs 2 / tan 55, the sides 2 / tan 45.
  expect_equal(sort(round(sb$setback[sb$setback > 0], 4)), sort(round(c(2 / tan(55 * pi / 180), 2, 2), 4)))
})

test_that("water yards are measured from the water, not from a boundary", {
  rb <- fixture_rulebook() |>
    set_rule("zones.A.setbacks", list(list(kind = "yard", distance = 15, boundaries = list("riparian"), source = "w")),
             validate = FALSE)
  river <- sf::st_sf(type = "river", geometry = sf::st_sfc(sf::st_linestring(rbind(c(-50, 80), c(150, 80))), crs = NZTM))
  e <- build_envelopes(scenario("R", rb, parcels = fixture_parcels(), roads = fixture_road(),
                                zoning = fixture_zoning(), water = river))
  # P6 (y 40-70) loses the 5 m strip within 15 m of the river at y = 80.
  expect_equal(e$stack$clipped_area[e$stack$site_id == "P6"][1], 20 * 25)
  expect_equal(e$stack$clipped_area[e$stack$site_id == "P1"][1], 600)
})

test_that("a density zone builds no envelope unless asked", {
  rb <- fixture_rulebook() |> set_rule("zones.A.method", "hybrid", validate = FALSE) |>
    set_rule("zones.B.method", "density", validate = FALSE)
  sc <- scenario("D", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
  e <- build_envelopes(sc)
  expect_true(all(e$sites$floor_area[e$sites$zone_key == "B"] == 0))
  expect_true(all(e$sites$floor_area[e$sites$zone_key == "A"] > 0))
  expect_true(all(build_envelopes(sc, include_density = TRUE)$sites$floor_area > 0))
})

test_that("a precinct's height replaces the zone's, roof allowance and all", {
  rb <- fixture_rulebook() |>
    set_rule("zones.A.height", list(value = 9, occupiable = 8, roof_allowance = 1, source = "z")) |>
    add_area(area("pre", "precincts", parameters = zone_changes(height = height_limit(12, source = "p")),
                  source = "p"))
  prec <- sf::st_sf(geometry = sf::st_sfc(rect(0, 0, 40, 30), crs = NZTM))
  e <- build_envelopes(scenario("P", rb, parcels = fixture_parcels(), roads = fixture_road(),
                                zoning = fixture_zoning(), layers = list(precincts = prec)))
  expect_identical(e$sites$storeys[e$sites$site_id == "P1"], 4L)   # 12 m in 3 m storeys
  expect_identical(e$sites$storeys[e$sites$site_id == "P6"], 2L)   # 8 m occupiable
})

# ---- Incremental runs --------------------------------------------------------------

test_that("an incremental run equals a full run and copies what did not change", {
  sc <- fixture_scenario()
  base <- build_envelopes(sc)
  ch <- scenario_change(sc, "B taller", rulebook = set_rule(sc$rulebook, "zones.B.height.value", 14))
  inc <- build_envelopes(ch, baseline = base)
  full <- build_envelopes(ch)
  expect_identical(inc$report$copied_from_baseline, 3L)      # the three A sites
  o1 <- order(inc$sites$site_id)
  o2 <- order(full$sites$site_id)
  expect_equal(inc$sites[o1, ], full$sites[o2, ], ignore_attr = TRUE)
  expect_equal(sum(full$sites$floor_area[full$sites$zone_key == "B"]), 3 * 600 * 4)
})

test_that("Exampleton builds, and every site is reported", {
  town <- exampleton()
  p <- town$parcels
  e <- build_envelopes(scenario("Operative", rulebook_example("exampleton"),
    parcels = p[p$parcel_type == "land", ], roads = p[p$parcel_type == "road", ],
    zoning = town$zoning, layers = town[c("height_areas", "precincts", "transit")],
    water = town$water))
  # Every parcel is reported (two are split by a zone boundary into two sites each).
  expect_identical(length(unique(sub("-z[0-9]+$", "", e$sites$site_id))), sum(p$parcel_type == "land"))
  expect_true(all(e$sites$floor_area > 0))
  tc <- e$sites[e$sites$zone_key == "TC", ]
  expect_true(all(tc$storeys == 7))     # 27 m: a 4.5 m ground floor and six of 3.5 m
  expect_true("front_exemption" %in% e$sites$variant)
})
