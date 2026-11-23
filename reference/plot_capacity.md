# Plot capacity

Plots of a capacity result. Each returns a ggplot object, so it can be
changed or added to, and carries a caption saying what the figures are.

## Usage

``` r
plot_capacity(
  cap,
  by = "zone",
  measure = "floor_area",
  fill = NULL,
  facet = NULL,
  top = 15,
  mode = "light",
  ...
)

plot_height_profile(cap, by = NULL, mode = "light")

plot_distribution(
  cap,
  measure = "floor_area",
  by = "zone",
  bins = 30,
  log = FALSE,
  zones = 6,
  mode = "light"
)

plot_constraints(cap, mode = "light")

plot_capacity_map(
  cap,
  measure = "floor_area",
  grid = NULL,
  areas = NULL,
  area_id = NULL,
  per_ha = TRUE,
  mode = "light"
)

plot_cumulative(cap, measure = "dwellings", by = NULL, mode = "light")
```

## Arguments

- cap:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- by:

  Grouping, as for
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md).

- measure:

  The measure to plot.

- fill:

  Optional second grouping, stacked within each bar.

- facet:

  Optional grouping for small multiples.

- top:

  Show at most this many bars; the rest are folded into "Other".

- mode:

  `"light"` or `"dark"` (see
  [`theme_capacity()`](https://faceteconomics.github.io/plancap/reference/theme_capacity.md)).

- ...:

  Passed to
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md)
  (for example `breaks`).

- bins:

  Histogram bins.

- log:

  Whether to plot the measure on a log scale.

- zones:

  At most this many zones (the largest by site count).

- grid, areas, area_id:

  Plot on a square grid of `grid` metres, or on `areas` labelled by
  `area_id`, instead of on sites.

- per_ha:

  Whether to map the measure per hectare of land.

## Value

A ggplot object.

## Details

- `plot_capacity()`: ranked bars by any grouping of
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md),
  optionally stacked by a second (`fill`) and faceted (`facet`);

- `plot_height_profile()`: floor area by storey, where capacity sits
  vertically, optionally split by zone;

- `plot_distribution()`: the distribution of a per-site measure, a small
  histogram per zone;

- `plot_constraints()`: a waterfall from the theoretical maximum to the
  enabled floor area
  ([`constraint_breakdown()`](https://faceteconomics.github.io/plancap/reference/constraint_breakdown.md));

- `plot_capacity_map()`: a map of capacity per hectare, on sites, a grid
  or areas;

- `plot_cumulative()`: the capacity curve, sites ranked by capacity per
  hectare: the share of capacity on each share of the land.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
cap <- estimate_capacity(sc)
plot_capacity(cap)

plot_capacity(cap, measure = "dwellings", fill = "height_band")

plot_height_profile(cap, by = "zone")

plot_constraints(cap)

plot_capacity_map(cap, grid = 100)

plot_cumulative(cap)
```
