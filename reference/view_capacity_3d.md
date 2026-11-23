# A 3D view of capacity

An interactive map of a capacity result, each site raised to the height
its envelope reaches and coloured by its capacity per hectare. With
`footprints = TRUE` each storey's footprint is drawn at its own level
instead, so the setbacks and planes show as the stepped form they make
(practical for a few thousand sites). Hover a site for its figures.
Needs the mapgl package; the basemap (OpenFreeMap's Positron, keyless)
is fetched when the map is viewed.

## Usage

``` r
view_capacity_3d(
  cap,
  measure = "floor_area",
  footprints = FALSE,
  style = NULL,
  pitch = 55,
  bearing = -20
)
```

## Arguments

- cap:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- measure:

  The measure to colour by, per hectare of land.

- footprints:

  Whether to draw each storey's footprint rather than the site raised to
  its height.

- style:

  A MapLibre style; default OpenFreeMap's Positron.

- pitch, bearing:

  The view angle.

## Value

An htmlwidget (a mapgl map).

## Examples

``` r
if (FALSE) { # interactive() && rlang::is_installed("mapgl")
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
view_capacity_3d(estimate_capacity(sc), footprints = TRUE)
}
```
