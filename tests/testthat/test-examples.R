test_that("every shipped rulebook is valid", {
  expect_setequal(rulebook_examples(), c("auckland", "christchurch", "exampleton", "exampleton_pc1", "hamilton", "wellington"))
  for (nm in rulebook_examples()) {
    rb <- rulebook_example(nm)
    v <- validate_rulebook(rb)
    expect_true(v$valid, info = nm)
  }
})

test_that("Exampleton's rulebook has no warnings and covers its map layers", {
  rb <- rulebook_example("exampleton")
  v <- validate_rulebook(rb)
  expect_equal(sum(v$issues$severity == "warning"), 0)
  town <- exampleton()
  layers <- c(vapply(rb$overlays, `[[`, "", "layer"), vapply(rb$areas, `[[`, "", "layer"))
  expect_true(all(layers %in% names(town)))
  expect_setequal(names(rb$zone_map), unique(town$zoning$zone))
  for (ov in rb$overlays) {
    if (!is.null(ov[["value_field"]])) expect_true(ov[["value_field"]] %in% names(town[[ov$layer]]))
  }
})

test_that("the council rulebooks round-trip through YAML", {
  for (nm in c("wellington", "christchurch")) {
    rb <- rulebook_example(nm)
    f <- withr::local_tempfile(fileext = ".yaml")
    write_rulebook(rb, f)
    expect_identical(to_plain(read_rulebook(f, validate = FALSE)), to_plain(rb), info = nm)
  }
})

test_that("Auckland keeps all 217 precincts", {
  rb <- rulebook_example("auckland")
  expect_length(rb$areas, 217)
  expect_true(any(vapply(rb$areas, function(a) !is.null(a$sub_areas), logical(1))))
})
