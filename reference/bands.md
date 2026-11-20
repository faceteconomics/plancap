# Banded values and ratios

Some rules change in steps with another quantity: building coverage that
falls as a site gets larger, plot ratio that depends on building height,
density reduced by slope. `bands()` holds such a rule;
[`ratio()`](https://faceteconomics.github.io/plancap/reference/ratio.md)
wraps a share of site area (a single value, a formula or bands) with its
source.

## Usage

``` r
bands(
  by = c("site_area", "height", "storey", "slope", "road_width", "distance",
    "site_depth"),
  upper,
  value,
  source = NULL
)

band_value(x, at, vars = list())
```

## Arguments

- by:

  What the bands are keyed on: `"site_area"` (m2), `"height"` (m, of the
  storey tested), `"storey"`, `"slope"` (per cent), `"road_width"` (m),
  `"distance"` (m) or `"site_depth"` (m).

- upper:

  Upper bound of each band, ascending.

- value:

  Value in each band. Numbers or formula strings.

- source:

  Citation.

- x:

  A `plancap_bands` object (or the equivalent list read from a file).

- at:

  Values of the `by` quantity to look up.

- vars:

  Variables for any formula values, see
  [`eval_rule_value()`](https://faceteconomics.github.io/plancap/reference/rule-formulas.md).

## Value

`bands()` returns a list with class `plancap_bands`; `band_value()` a
numeric vector.

## Details

Bands are closed on the right: a site of exactly 200 m2 falls in a band
with `upper = 200`. The last band's upper bound may be `Inf`.

## Examples

``` r
# Coverage that falls with site size
cov <- bands("site_area", upper = c(200, 300, 500, Inf),
             value = c(0.55, 0.45, 0.40, 0.35))
band_value(cov, c(150, 200, 450, 1000))
#> [1] 0.55 0.55 0.40 0.35
```
