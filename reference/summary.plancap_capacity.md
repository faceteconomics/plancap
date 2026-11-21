# Summarise a capacity result

The headline (sites, land, floor area, dwellings), capacity by zone, and
a tally of flags and binding constraints.

## Usage

``` r
# S3 method for class 'plancap_capacity'
summary(object, ...)
```

## Arguments

- object:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- ...:

  Unused.

## Value

A `plancap_capacity_summary` list: `headline`, `by_zone`, `flags` and
`binding`, printed readably.
