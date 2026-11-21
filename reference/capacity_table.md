# A formatted capacity table

Formats a summary as a `gt` table, with readable numbers, a title and a
source note stating what the figures are. Without the gt package,
returns the formatted data frame.

## Usage

``` r
capacity_table(x, title = NULL, ...)
```

## Arguments

- x:

  A summary from
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md)
  (or a capacity result, summarised by zone).

- title:

  Optional title; default names the scenario.

- ...:

  Passed to
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md)
  when `x` is a capacity result.

## Value

A `gt_tbl`, or a data frame.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
capacity_table(estimate_capacity(sc))


  


Plan-enabled capacity: Operative
```
