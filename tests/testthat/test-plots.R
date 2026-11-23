# Plots build without error and carry what they should. The fixture: six
# 600 m2 lots in zones A (8 m) and B (11 m).

plot_cap <- function() {
  estimate_capacity(scenario("Plots", set_conversion(fixture_rulebook(), conversion(dwelling_size = 100)),
                             parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning()))
}
builds <- function(p) {
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
}

test_that("the palette has eight slots and folds the rest into Other", {
  expect_length(capacity_palette("categorical"), 8)
  expect_error(capacity_palette("categorical", 9), "eight")
  expect_false(identical(capacity_palette("categorical", mode = "dark"), capacity_palette("categorical")))
  expect_named(capacity_palette("diverging"), c("loss", "mid", "gain"))
  f <- fold_other(letters[1:10], 10:1, k = 4)
  expect_identical(levels(f), c("a", "b", "c", "Other"))
  expect_s3_class(theme_capacity(), "theme")
  expect_s3_class(theme_capacity("dark"), "theme")
})

test_that("labels use one style per set", {
  expect_identical(label_count(c(500, 4000)), c("500", "4,000"))
  expect_identical(label_count(c(4000, 12000)), c("4K", "12K"))
  expect_identical(label_count(2.5e6), "2.5M")
  expect_identical(label_area(600), "600 m²")
  expect_identical(label_signed(label_count)(c(-5, 5)), c("-5", "+5"))
})

test_that("capacity plots build", {
  cap <- plot_cap()
  p <- plot_capacity(cap)
  builds(p)
  expect_match(p$labels$caption, "dwellings at 100 m²")
  builds(plot_capacity(cap, measure = "dwellings", fill = "height_band"))
  builds(plot_capacity(cap, facet = "height_band"))
  builds(plot_height_profile(cap))
  builds(plot_height_profile(cap, by = "zone"))
  builds(plot_distribution(cap))
  builds(plot_constraints(cap))
  builds(plot_capacity_map(cap))
  builds(plot_capacity_map(cap, grid = 30))
  builds(plot_cumulative(cap))
  builds(plot_cumulative(cap, by = "zone"))
  builds(plot_site(cap, "P1"))
  builds(plot_site(cap, "P1", view = "axo", mode = "dark"))
  expect_error(plot_site(cap, "nope"), "No site")
})

test_that("zones keep their colour from plot to plot", {
  cap <- plot_cap()
  a <- ggplot2::ggplot_build(plot_height_profile(cap, by = "zone"))
  f <- levels(a$plot$data$.fill)
  expect_identical(f, c("A", "B"))
})

test_that("comparison and sensitivity plots build", {
  base <- scenario("Base", set_conversion(fixture_rulebook(), conversion(dwelling_size = 100)),
                   parcels = fixture_parcels(), roads = fixture_road(), zoning = fixture_zoning())
  rez <- scenario_change(base, "Rezoned", zoning = fixture_zoning(split = 60))
  cmp <- compare_scenarios(run_scenarios(scenario_set(base, rez), progress = FALSE), grid = 30)
  builds(plot_comparison(cmp))
  builds(plot_comparison(cmp, type = "bars", measure = "dwellings"))
  builds(plot_comparison(cmp, by = "grid"))
  builds(plot_change_map(cmp))
  builds(plot_change_map(cmp, on = "grid"))
  builds(plot_transitions(cmp))
  builds(plot_transitions(cmp, measure = "floor_area"))
  builds(plot_attribution(cmp))
  expect_error(plot_comparison(cmp, by = "area"), "no area")
  s <- sensitivity(base, "zones.A.height", list(height_limit(8, storeys = 2, source = "a"),
                                                height_limit(11, storeys = 3, source = "b")), by = "zone")
  builds(plot_sensitivity(s))
})

test_that("the dashboard lays out four plots", {
  skip_if_not_installed("patchwork", "1.3.1")
  expect_s3_class(autoplot(plot_cap()), "patchwork")
})
