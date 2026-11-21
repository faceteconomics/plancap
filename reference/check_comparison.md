# Reconcile a comparison

Checks that every view of a comparison adds up: the drivers sum to the
total change, and the zone transitions, the zone and height summaries,
the common geography and the site-level changes each reproduce both
scenarios' totals.

## Usage

``` r
check_comparison(cmp, tolerance = 1e-06)
```

## Arguments

- cmp:

  A comparison from
  [`compare_scenarios()`](https://faceteconomics.github.io/plancap/reference/compare_scenarios.md).

- tolerance:

  Relative tolerance.

## Value

A data frame of class `plancap_checks`.
