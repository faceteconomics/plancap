test_that("grouping parcels into one site removes their shared boundary", {
  clear_site_cache()
  by_parcel <- prepare_sites(fixture_scenario())
  by_title <- prepare_sites(fixture_scenario(group_by = "title_id"))
  expect_equal(sum(by_parcel$segments$length[by_parcel$segments$site_id %in% c("P4", "P5")]), 200)
  merged <- by_title$sites$site_id[vapply(by_title$sites$parcel_ids, function(p) setequal(p, c("P4", "P5")), TRUE)]
  expect_length(merged, 1)
  expect_equal(sum(by_title$segments$length[by_title$segments$site_id == merged]), 140)
})

test_that("the zone across a boundary is read from the far side", {
  s <- prepare_sites(fixture_scenario())
  p1 <- seg_of(s$segments, "P1")
  east <- p1[p1$outward_bearing == 90, ]
  west <- p1[p1$outward_bearing == 270, ]
  expect_identical(s$sites$zone_key[s$sites$site_id == "P1"], "A")
  expect_identical(east$adjacent_zone_key, "B")
  expect_identical(west$adjacent_zone_key, "A")
  expect_match(east$adjacent_tokens, "|B|RES|", fixed = TRUE)
})

test_that("a road frontage reads the zone across the carriageway", {
  across <- sf::st_sf(zone = c("A", "B"),
                      geometry = sf::st_sfc(rect(-200, -20, 300, 300), rect(-200, -100, 300, -20), crs = NZTM))
  s <- prepare_sites(fixture_scenario(zoning = across))
  front <- seg_of(s$segments, "P1")
  front <- front[front$boundary_class == "road", ]
  expect_identical(front$adjacent_zone_key, "B")
  short <- prepare_sites(fixture_scenario(zoning = across, morphology = list(road_probe_distance = 1)))
  fs <- seg_of(short$segments, "P1")
  expect_identical(fs$adjacent_zone_key[fs$boundary_class == "road"], "A")
})

test_that("a boundary onto open space is tagged reserve with the reserve's whole area", {
  # Two abutting open space polygons north of P6 count as one reserve.
  z <- sf::st_sf(zone = c("A", "OS", "OS"),
                 geometry = sf::st_sfc(rect(-200, -100, 300, 70), rect(-200, 70, 30, 100),
                                       rect(30, 70, 300, 100), crs = NZTM))
  s <- prepare_sites(fixture_scenario(zoning = z))
  p6 <- seg_of(s$segments, "P6")
  north <- p6[p6$outward_bearing == 0, ]
  expect_match(north$tags, "|reserve|", fixed = TRUE)
  expect_identical(north$boundary_class, "side")  # keeps its class (P6 has no frontage)
  expect_equal(north$adjacent_area, 500 * 30)
})

test_that("a site two zones cross is split, and only it is reclassified", {
  s <- prepare_sites(fixture_scenario(zoning = fixture_zoning(split = 30)))
  pieces <- s$sites[s$sites$parent_id == "P1", ]
  expect_identical(nrow(pieces), 2L)
  expect_setequal(pieces$zone_key, c("A", "B"))
  expect_equal(sum(pieces$area), 600)
  # x = 30 crosses P1 and P6 (both x 20-40): the shared edge once per piece.
  zb <- s$segments[grepl("zone_boundary", s$segments$tags), ]
  expect_identical(nrow(zb), 4L)
  expect_setequal(zb$parent_id, c("P1", "P6"))
  expect_identical(s$report$sites_split, 2L)
  # Every other site keeps its id.
  expect_true(all(c("P7", "P2", "P4", "P5") %in% s$sites$site_id))
})

test_that("a sliver of another zone joins the site's main piece", {
  s <- prepare_sites(fixture_scenario(zoning = fixture_zoning(split = 39.99)))
  expect_false(any(grepl("-z", s$sites$site_id)))
  expect_identical(s$sites$zone_key[s$sites$site_id == "P1"], "A")
  expect_equal(sum(s$sites$area), 6 * 600)
})

test_that("unmapped zone codes and missing layers are reported, not dropped", {
  z <- fixture_zoning()
  z$zone[2] <- "MYSTERY"
  rb <- fixture_rulebook() |>
    add_overlay(overlay("flood", "exclusion", layer = "flood_map", source = "x"))
  s <- prepare_sites(scenario("X", rb, parcels = fixture_parcels(), roads = fixture_road(), zoning = z))
  expect_identical(s$report$unmapped_zone_codes, "MYSTERY")
  expect_true(is.na(s$sites$zone_key[s$sites$site_id == "P2"]))
  expect_identical(s$sites$zone_code[s$sites$site_id == "P2"], "MYSTERY")
  expect_identical(s$report$overlay_layers_missing, "flood_map")
  expect_identical(nrow(s$sites), 6L)
})

test_that("overlay and area membership record the share of each site covered", {
  rb <- fixture_rulebook() |>
    add_overlay(overlay("hc", "height", layer = "heights", value_field = "h", source = "x")) |>
    add_area(area("pre", "precincts", sub_area_field = "sub",
                  sub_areas = list(S = zone_changes(height = height_limit(20, source = "y"))), source = "y"))
  heights <- sf::st_sf(h = 16, geometry = sf::st_sfc(rect(30, -10, 50, 40), crs = NZTM))
  prec <- sf::st_sf(sub = "S", geometry = sf::st_sfc(rect(0, 0, 20, 30), crs = NZTM))
  s <- prepare_sites(scenario("X", rb, parcels = fixture_parcels(), roads = fixture_road(),
                              zoning = fixture_zoning(), layers = list(heights = heights, precincts = prec)))
  o <- s$overlays
  expect_equal(o$share[o$site_id == "P1"], 0.5)
  expect_equal(o$share[o$site_id == "P2"], 0.5)
  expect_equal(unique(o$value), 16)
  expect_identical(s$areas$sub_area[s$areas$site_id == "P7"], "S")
  expect_equal(s$areas$share[s$areas$site_id == "P7"], 1)
})

test_that("distances are measured to layers that rules name", {
  rb <- fixture_rulebook() |>
    add_bonus(bonus("near", "height", 3, when = conditions(distance_to = "stations", max_distance = 50), source = "x"))
  st <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(30, 100)), crs = NZTM))
  s <- prepare_sites(scenario("X", rb, parcels = fixture_parcels(), roads = fixture_road(),
                              zoning = fixture_zoning(), layers = list(stations = st)))
  expect_equal(s$distances$distance[s$distances$site_id == "P6"], 30)
})

test_that("prepared parts are reused when their inputs are unchanged", {
  clear_site_cache()
  base <- fixture_scenario()
  a <- prepare_sites(base)
  expect_false(any(a$reused))
  rule_only <- scenario_change(base, "taller", rulebook = set_rule(base$rulebook, "zones.A.height.value", 12))
  expect_true(all(prepare_sites(rule_only)$reused))
  rezoned <- scenario_change(base, "rezoned", zoning = fixture_zoning(split = 20))
  r <- prepare_sites(rezoned)
  expect_identical(r$reused, c(parcel_geometry = TRUE, plan_geometry = FALSE))
  expect_identical(r$sites$zone_key[r$sites$site_id == "P1"], "B")
  new_parcels <- scenario_change(base, "subdivided", parcels = fixture_parcels()[-1, ])
  expect_false(any(prepare_sites(new_parcels)$reused))
  expect_false(any(prepare_sites(base, cache = FALSE)$reused))
})

test_that("scenario_change merges layers by name", {
  base <- fixture_scenario(layers = list(a = fixture_road(), b = fixture_road()))
  ch <- scenario_change(base, "c", layers = list(a = NULL, c = fixture_road()))
  expect_setequal(names(ch$layers), c("b", "c"))
  expect_identical(ch$changed_from, "Fixture")
  expect_error(scenario_change(base, "x", nonsense = 1), "Unknown")
})

test_that("Exampleton prepares as built", {
  town <- exampleton()
  p <- town$parcels
  s <- prepare_sites(scenario("Operative", rulebook_example("exampleton"),
    parcels = p[p$parcel_type == "land", ], roads = p[p$parcel_type == "road", ],
    zoning = town$zoning, layers = town[c("height_areas", "flood_hazard", "heritage", "trees", "precincts", "transit")],
    water = town$water, centrelines = town$road_centrelines, group_by = "title_id"))
  st <- sf::st_drop_geometry(s$sites)
  form <- p$lot_form[match(st$parent_id, p$parcel_id)]
  expect_identical(sum(st$is_through), 9L)
  expect_true(all(st$is_through == (form == "through")))
  # Every rear lot found to be a rear site has its access leg; no front lot has one.
  whole <- st$site_id == st$parent_id
  expect_true(all(st$access_leg_area[whole & st$is_rear & form == "rear"] > 0))
  expect_identical(sum(st$access_leg_area > 0 & form == "front"), 0L)
  expect_equal(sum(st$area), sum(as.numeric(sf::st_area(p[p$parcel_type == "land", ]))))
  expect_true(all(check_morphology(s)$status %in% c("ok", "n/a")))
  expect_s3_class(plot_morphology(s, sites = "P00180", pad = 40), "ggplot")
  msgs <- capture.output(print(s), type = "message")
  expect_true(any(grepl("plancap sites", msgs)))
})
