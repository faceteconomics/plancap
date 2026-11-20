# Required setback distance at a height

Evaluates a setback rule at one or more heights. The engine calls this
for every boundary at every storey; it is exported so rules can be
checked and plotted on their own.

## Usage

``` r
setback_distance(
  rule,
  height,
  storey = NA_integer_,
  bearing = NA_real_,
  vars = list()
)
```

## Arguments

- rule:

  A setback from
  [`yard()`](https://faceteconomics.github.io/plancap/reference/yard.md),
  [`plane()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  and friends (or the same structure read from a rulebook file).

- height:

  Height(s) above the datum (m) at which to evaluate.

- storey:

  Storey number(s) for rules with `from_storey`; defaults to `NA`, which
  counts as satisfying any storey condition.

- bearing:

  Bearing(s) of the boundary's outward normal (degrees clockwise from
  north), for planes whose angle depends on orientation.

- vars:

  Other variables for formula values, see
  [`eval_rule_value()`](https://faceteconomics.github.io/plancap/reference/rule-formulas.md).

## Value

Numeric vector of required distances (m), one per height.

## Examples

``` r
p <- plane(angle_deg = 45, start_height = 2.5, boundaries = "side")
setback_distance(p, c(2, 3, 6, 9))
#> [1] 0.0 0.5 3.5 6.5
setback_distance(proportional_setback(0.4, "side", min = 3), c(3, 10, 20))
#> [1] 3 4 8
```
