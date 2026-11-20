# Rule values written as formulas

Many planning rules state a value as a formula rather than a number: a
setback of "0.4 times the wall height, at least 3 m", a floor area ratio
of "the front road width times 0.4", a rear yard of "25 per cent of lot
depth". Anywhere a rulebook takes a number it also takes a formula,
written as a string, e.g. `"max(3, 0.4 * H)"`.

## Usage

``` r
rule_formula_vars(x)

eval_rule_value(value, vars = list())
```

## Arguments

- x:

  A formula string.

- value:

  A number or a formula string.

- vars:

  A named list of variable values. Vectors are allowed and recycled, so
  a formula can be evaluated for many sites or storeys at once.

## Value

`rule_formula_vars()` returns the variable names a formula uses.
`eval_rule_value()` returns a numeric vector.

## Details

Formulas are **restricted**: they are parsed, checked against a fixed
list of variables and functions, and evaluated without access to
anything else, so a rulebook from an untrusted source cannot run
arbitrary code.

## Variables

- `H`:

  Height above ground of the storey being tested (m).

- `storey`:

  Storey number, 1 at ground.

- `site_area`:

  Site area (m2).

- `site_depth`, `site_width`:

  Site depth and width (m).

- `frontage`:

  Length of road frontage (m).

- `n_frontages`:

  Number of roads the site fronts.

- `road_width`:

  Width of the road reserve in front of the site (m).

- `slope`:

  Average site slope (per cent).

- `distance`:

  Distance to the feature named in the rule (m).

- `corner`:

  1 on a corner site, otherwise 0.

## Functions

Arithmetic (`+ - * / ^`), comparison (`< <= > >= == !=`), `&`, `|`, `!`,
and [`min()`](https://rdrr.io/r/base/Extremes.html),
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`abs()`](https://rdrr.io/r/base/MathFun.html),
[`floor()`](https://rdrr.io/r/base/Round.html),
[`ceiling()`](https://rdrr.io/r/base/Round.html),
[`round()`](https://rdrr.io/r/base/Round.html),
[`sqrt()`](https://rdrr.io/r/base/MathFun.html),
[`ifelse()`](https://rdrr.io/r/base/ifelse.html), `clamp(x, lo, hi)`,
`step(x, breaks, values)` (the value of the band `x` falls in) and
`interp(x, xs, ys)` (straight-line interpolation between points).

## Examples

``` r
eval_rule_value("max(3, 0.4 * H)", list(H = c(5, 10, 20)))
#> [1] 3 4 8
eval_rule_value("road_width * 0.4", list(road_width = 8))
#> [1] 3.2
eval_rule_value(12)
#> [1] 12
rule_formula_vars("max(3, 0.4 * H) + 0 * site_area")
#> [1] "H"         "site_area"
```
