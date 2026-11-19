test_that("formulas evaluate and vectorise", {
  expect_equal(eval_rule_value("max(3, 0.4 * H)", list(H = c(5, 10, 20))), c(3, 4, 8))
  expect_equal(eval_rule_value("road_width * 0.4", list(road_width = 8)), 3.2)
  expect_equal(eval_rule_value(12), 12)
  expect_equal(eval_rule_value("clamp(H, 2, 5)", list(H = c(1, 3, 9))), c(2, 3, 5))
  expect_equal(eval_rule_value("step(site_area, c(200, 500), c(0.5, 0.4, 0.3))",
                               list(site_area = c(100, 300, 900))), c(0.5, 0.4, 0.3))
  expect_equal(eval_rule_value("interp(H, c(0, 10), c(1, 3))", list(H = 5)), 2)
})

test_that("formulas are restricted to known variables and functions", {
  expect_error(eval_rule_value("system('echo hi')"), "not allowed")
  expect_error(eval_rule_value("foo * 2"), "unknown variable")
  expect_error(eval_rule_value("H +"), "not a valid formula")
  expect_error(eval_rule_value("H * 2"), "needs")
  expect_equal(rule_formula_vars("max(3, 0.4 * H) + 0 * site_area"), c("H", "site_area"))
})
