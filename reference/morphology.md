# Identify what each boundary and site is

Before any rule can apply, every boundary has to be identified as a road
frontage, side or rear boundary, and every site as a corner, through or
rear site, with or without an access leg. These helpers do that, each
returning the classification **and the evidence** for it, so a wrong
call can be traced. All of them follow the same assumptions, from
[`morphology_defaults()`](https://faceteconomics.github.io/plancap/reference/morphology_defaults.md),
a rulebook's `morphology` block and the `morphology` argument, in that
order of increasing precedence.

## Usage

``` r
find_road_frontages(sites, roads, rulebook = NULL, morphology = list())

find_side_rear(sites, roads, rulebook = NULL, morphology = list())

find_corner_sites(sites, roads, rulebook = NULL, morphology = list())

find_through_sites(sites, roads, rulebook = NULL, morphology = list())

find_rear_sites(sites, roads, rulebook = NULL, morphology = list())

find_access_legs(sites, roads, rulebook = NULL, morphology = list())

find_water_boundaries(sites, water, rulebook = NULL, morphology = list())

find_road_widths(
  sites,
  roads,
  centrelines = NULL,
  width_field = "width_m",
  rulebook = NULL,
  morphology = list()
)

site_metrics(sites, roads = NULL, rulebook = NULL, morphology = list())
```

## Arguments

- sites:

  An `sf` polygon layer of sites (or parcels) in a projected CRS, with a
  `site_id` column (created if missing).

- roads:

  Road parcels (polygons), or `NULL`. Without them no boundary is a road
  frontage.

- rulebook:

  Optional rulebook whose `morphology` settings apply.

- morphology:

  Named list overriding individual settings for this run.

- water:

  Water features (lines or polygons), optionally with a `type` column
  (`"river"`, `"stream"`, `"coast"`, `"lake"`).

- centrelines:

  Optional road centrelines with a road reserve width column, see
  `width_field`.

- width_field:

  Column of `centrelines` holding the road width (m).

## Value

`find_road_frontages()`, `find_side_rear()` and
`find_water_boundaries()` return an `sf` table of boundary segments;
`find_access_legs()` an `sf` table of access legs; the others a data
frame with one row per site.

## Details

- `find_road_frontages()`: boundary segments that run along a road
  parcel.

- `find_side_rear()`: the other boundaries, as side or rear, from their
  angle to the frontage and how far back they sit.

- `find_corner_sites()`, `find_through_sites()`, `find_rear_sites()`:
  site types, from the directions the frontages face and the frontage
  length.

- `find_access_legs()`: the narrow strip by which a rear site reaches
  the road (a driveway or "battle-axe handle").

- `find_water_boundaries()`: boundaries near a river, the coast or a
  lake.

- `find_road_widths()`: width of the road in front of each site.

- `site_metrics()`: area, frontage, depth, width and compactness.

Boundaries get one **class**, `road`, `side` or `rear`, and any number
of **tags** (`riparian`, `coastal`, `lakeside`, `reserve`,
`zone_boundary`). A setback rule naming a tag in its `boundaries`
applies to boundaries with that tag, so a river boundary stays a side or
rear boundary for every other rule.

## Examples

``` r
town <- exampleton()
land <- town$parcels[town$parcels$parcel_type == "land", ][1:60, ]
roads <- town$parcels[town$parcels$parcel_type == "road", ]
head(find_rear_sites(land, roads))
#>   site_id frontage is_rear access_leg_area
#> 1 S000001 64.28599   FALSE               0
#> 2 S000002 20.52427   FALSE               0
#> 3 S000003 15.56643   FALSE               0
#> 4 S000004 16.77586   FALSE               0
#> 5 S000005  4.00000    TRUE              88
#> 6 S000006 19.21431   FALSE               0
legs <- find_access_legs(land, roads)
nrow(legs)
#> [1] 8
```
