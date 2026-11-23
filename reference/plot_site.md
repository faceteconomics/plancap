# Plot one site's envelope

The site with its boundaries coloured by class and its storey
footprints: in plan (`view = "plan"`), the footprints shaded from the
ground storey (light) to the top (dark); or as an axonometric stack
(`view = "axo"`), each storey's footprint drawn at its height.

## Usage

``` r
plot_site(cap, site_id, view = c("plan", "axo"), mode = "light")
```

## Arguments

- cap:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- site_id:

  The site.

- view:

  `"plan"` or `"axo"`.

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
cap <- estimate_capacity(sc)
plot_site(cap, "P00001")

plot_site(cap, "P00001", view = "axo")
```
