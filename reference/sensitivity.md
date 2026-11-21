# Sweep a rule through a set of values

Runs capacity with one rule set to each of `values` in turn and returns
a tidy table of the results, so the effect of a height limit, a
recession plane angle or a site area per dwelling can be read or
plotted. Each run after the first is incremental: only sites whose rules
change are rebuilt.

## Usage

``` r
sensitivity(
  x,
  rule,
  values,
  by = NULL,
  measures = c("floor_area", "dwellings"),
  ...
)
```

## Arguments

- x:

  A
  [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md).

- rule:

  Path of the rule to change, as for
  [`set_rule()`](https://faceteconomics.github.io/plancap/reference/set_rule.md),
  such as `"zones.MDR.ratios.coverage_max.value"`. A height is several
  linked values (total, occupiable, storeys); sweep it by giving whole
  [`height_limit()`](https://faceteconomics.github.io/plancap/reference/height_limit.md)s
  as `values`, at path `"zones.MDR.height"`.

- values:

  The values to try: numbers, formulas as strings, or a list of whole
  rules (then `value` in the result is the position in the list).

- by:

  Optional grouping, as for
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md).

- measures:

  Measures, as for
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md).

- ...:

  Passed to
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

## Value

A data frame of class `plancap_sensitivity`: `value`, the grouping
columns, the measures, and `floor_area_change` and `dwellings_change`
against the first value where those measures are asked for.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
sensitivity(sc, "zones.MDR.ratios.coverage_max.value", c(0.4, 0.5, 0.6), by = "zone")
#> <plancap sensitivity> Operative: zones.MDR.ratios.coverage_max.value
#>  value zone_key floor_area dwellings floor_area_change dwellings_change
#>    0.4      HDR    529,519     5,594                 0                0
#>    0.4      IND    115,200         0                 0                0
#>    0.4      LDR     64,920       103                 0                0
#>    0.4      MDR    601,861     6,171                 0                0
#>    0.4       MU    384,000     2,132                 0                0
#>    0.4       TC    256,000     1,342                 0                0
#>    0.5      HDR    529,519     5,594                 0                0
#>    0.5      IND    115,200         0                 0                0
#>    0.5      LDR     64,920       103                 0                0
#>    0.5      MDR    737,704     7,644           135,843            1,473
#>    0.5       MU    384,000     2,132                 0                0
#>    0.5       TC    256,000     1,342                 0                0
#>    0.6      HDR    529,519     5,594                 0                0
#>    0.6      IND    115,200         0                 0                0
#>    0.6      LDR     64,920       103                 0                0
#>    0.6      MDR    855,072     8,890           253,211            2,719
#>    0.6       MU    384,000     2,132                 0                0
#>    0.6       TC    256,000     1,342                 0                0
```
