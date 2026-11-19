#' Rule values written as formulas
#'
#' Many planning rules state a value as a formula rather than a number: a
#' setback of "0.4 times the wall height, at least 3 m", a floor area ratio of
#' "the front road width times 0.4", a rear yard of "25 per cent of lot depth".
#' Anywhere a rulebook takes a number it also takes a formula, written as a
#' string, e.g. `"max(3, 0.4 * H)"`.
#'
#' Formulas are **restricted**: they are parsed, checked against a fixed list of
#' variables and functions, and evaluated without access to anything else, so a
#' rulebook from an untrusted source cannot run arbitrary code.
#'
#' @section Variables:
#' \describe{
#'   \item{`H`}{Height above ground of the storey being tested (m).}
#'   \item{`storey`}{Storey number, 1 at ground.}
#'   \item{`site_area`}{Site area (m2).}
#'   \item{`site_depth`, `site_width`}{Site depth and width (m).}
#'   \item{`frontage`}{Length of road frontage (m).}
#'   \item{`n_frontages`}{Number of roads the site fronts.}
#'   \item{`road_width`}{Width of the road reserve in front of the site (m).}
#'   \item{`slope`}{Average site slope (per cent).}
#'   \item{`distance`}{Distance to the feature named in the rule (m).}
#'   \item{`corner`}{1 on a corner site, otherwise 0.}
#' }
#'
#' @section Functions:
#' Arithmetic (`+ - * / ^`), comparison (`< <= > >= == !=`), `&`, `|`, `!`,
#' and `min()`, `max()`, `abs()`, `floor()`, `ceiling()`, `round()`,
#' `sqrt()`, `ifelse()`, `clamp(x, lo, hi)`, `step(x, breaks, values)` (the
#' value of the band `x` falls in) and `interp(x, xs, ys)` (straight-line
#' interpolation between points).
#'
#' @param x A formula string.
#' @param vars A named list of variable values. Vectors are allowed and
#'   recycled, so a formula can be evaluated for many sites or storeys at once.
#' @return `rule_formula_vars()` returns the variable names a formula uses.
#'   `eval_rule_value()` returns a numeric vector.
#' @name rule-formulas
#' @examples
#' eval_rule_value("max(3, 0.4 * H)", list(H = c(5, 10, 20)))
#' eval_rule_value("road_width * 0.4", list(road_width = 8))
#' eval_rule_value(12)
#' rule_formula_vars("max(3, 0.4 * H) + 0 * site_area")
NULL

formula_variables <- c("H", "storey", "site_area", "site_depth", "site_width",
                       "frontage", "n_frontages", "road_width", "slope",
                       "distance", "corner")

formula_functions <- c("+", "-", "*", "/", "^", "(", "<", "<=", ">", ">=", "==",
                       "!=", "&", "|", "!", "min", "max", "abs", "floor",
                       "ceiling", "round", "sqrt", "ifelse", "clamp", "step",
                       "interp", "c")

formula_env <- function() {
  env <- new.env(parent = emptyenv())
  for (f in c("+", "-", "*", "/", "^", "(", "<", "<=", ">", ">=", "==", "!=",
              "&", "|", "!", "abs", "floor", "ceiling", "round", "sqrt",
              "ifelse", "c")) {
    assign(f, get(f, envir = baseenv()), envir = env)
  }
  # min and max act element-wise so formulas vectorise over sites and storeys.
  assign("min", function(...) pmin(...), envir = env)
  assign("max", function(...) pmax(...), envir = env)
  assign("clamp", function(x, lo, hi) pmin(pmax(x, lo), hi), envir = env)
  assign("step", function(x, breaks, values) {
    if (length(values) != length(breaks) + 1) {
      stop("step() needs one more value than breaks", call. = FALSE)
    }
    values[findInterval(x, breaks) + 1]
  }, envir = env)
  assign("interp", function(x, xs, ys) {
    stats::approx(xs, ys, xout = x, rule = 2)$y
  }, envir = env)
  env
}

parse_rule_formula <- function(x, arg = "formula", call = rlang::caller_env()) {
  expr <- tryCatch(str2lang(x), error = function(e) {
    cli::cli_abort(c("{.arg {arg}} is not a valid formula: {.val {x}}.",
                     "x" = conditionMessage(e)), call = call)
  })
  walk <- function(e) {
    if (is.call(e)) {
      fn <- e[[1]]
      if (!is.symbol(fn) || !as.character(fn) %in% formula_functions) {
        cli::cli_abort(c("{.arg {arg}} uses a function that is not allowed: {.code {deparse(fn)}}.",
                         "i" = "Allowed: {.code {setdiff(formula_functions, c('(', 'c'))}}."),
                       call = call)
      }
      lapply(as.list(e)[-1], walk)
    } else if (is.symbol(e)) {
      if (!as.character(e) %in% formula_variables) {
        cli::cli_abort(c("{.arg {arg}} uses an unknown variable: {.code {as.character(e)}}.",
                         "i" = "Known variables: {.code {formula_variables}}."), call = call)
      }
    } else if (!(is.numeric(e) || is.logical(e))) {
      cli::cli_abort("{.arg {arg}} may contain only numbers, variables and allowed functions.",
                     call = call)
    }
    invisible(NULL)
  }
  walk(expr)
  expr
}

#' @rdname rule-formulas
#' @export
rule_formula_vars <- function(x) {
  check_string(x, null_ok = FALSE)
  expr <- parse_rule_formula(x)
  intersect(all.vars(expr), formula_variables)
}

#' @rdname rule-formulas
#' @param value A number or a formula string.
#' @export
eval_rule_value <- function(value, vars = list()) {
  if (is.null(value)) return(NULL)
  if (is.numeric(value)) return(as.numeric(value))
  check_string(value, null_ok = FALSE)
  expr <- parse_rule_formula(value)
  needed <- intersect(all.vars(expr), formula_variables)
  missing <- setdiff(needed, names(vars))
  if (length(missing)) {
    cli::cli_abort("Formula {.val {value}} needs {.field {missing}}, which {?was/were} not supplied.")
  }
  env <- formula_env()
  data <- list2env(vars[needed], parent = env)
  out <- eval(expr, data)
  as.numeric(out)
}

is_formula <- function(x) is_string(x)
