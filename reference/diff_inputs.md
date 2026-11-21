# What differs between two scenarios' inputs

The rule changes as a table (every rule of
[`rule_table()`](https://faceteconomics.github.io/plancap/reference/rule_table.md)
added, removed or given a new value), and the map changes as polygons:
land rezoned (from and to which zone), each overlay or area layer's land
added or removed, and parcels changed.

## Usage

``` r
diff_inputs(a, b)
```

## Arguments

- a, b:

  Two
  [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md)s,
  the baseline first.

## Value

A `plancap_input_diff` list: `fields` (the scenario inputs that differ),
`rules`, `rezoned` (`sf`), `layers` (`sf`: layer, change) and `parcels`
(`sf`: parcel geometry only in one scenario, and which).
