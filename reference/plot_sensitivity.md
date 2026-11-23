# Plot a rule sweep

Plot a rule sweep

## Usage

``` r
plot_sensitivity(sens, measure = "floor_area", mode = "light")
```

## Arguments

- sens:

  A result of
  [`sensitivity()`](https://faceteconomics.github.io/plancap/reference/sensitivity.md).

- measure:

  The measure.

- mode:

  `"light"` or `"dark"`.

## Value

A ggplot object.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
s <- sensitivity(sc, "zones.MDR.ratios.coverage_max.value", c(0.3, 0.4, 0.5, 0.6))
plot_sensitivity(s)
```
