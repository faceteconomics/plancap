# The site shape factor: can a site hold the plan's rectangle?

Some plans require every vacant site created by subdivision to hold a
rectangle of a stated size clear of its yards (Auckland Unitary Plan
E38.8.1.1(2): 8 m by 15 m, 15 m by 20 m in the Terrace Housing and
Apartment Buildings zone). A zone states its rectangle as
`form$site_shape` (`width`, `depth`; see
[`building_form()`](https://faceteconomics.github.io/plancap/reference/building_form.md)).

## Usage

``` r
site_shape_factor(x, site_ids = NULL, angle_step = 5, cell = 0.25)
```

## Arguments

- x:

  A
  [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md).

- site_ids:

  Sites to test. Default: sites in density zones with a rectangle that
  are at least twice the zone's vacant site minimum (smaller sites count
  one dwelling whatever their shape).

- angle_step:

  Sweep step of the exact test, degrees.

- cell:

  Raster cell of the exact test, metres.

## Value

A data frame, one row per site tested: `site_id`, `rect_width`,
`rect_depth`, `developable_area`, `fits`, `max_lots` and `decided_by`
(`"area"`, `"rotated_rectangle"`, `"inscribed_disc"`, `"aligned"` or
`"raster"`).

## Details

The rule governs creating vacant sites, so it bears on the subdivision
paths only (density, large site, and a hybrid zone taking its density
count);
[`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md)
applies it there. A site that cannot hold one rectangle creates no new
site and keeps one dwelling; none creates more sites than its
developable area holds rectangles (a necessary bound, not a packing).

**The developable area** is the site less the zone's yards (each a
flat-ended strip along the boundaries it applies to), less water yards
and the land exclusion overlays take off.

**The test, at any orientation**, cheapest first:

1.  it *fails* if the area is under width x depth, if its minimum
    rotated rectangle is narrower than the width or shorter than the
    depth, or if it cannot hold a disc as wide as the rectangle;

2.  it *passes* if the rectangle fits laid along the minimum rotated
    rectangle's axes, at its centre or at a point well inside the area;

3.  otherwise it is decided *exactly to a grid*: the area is rasterised
    at `cell` in a frame turned to each of its own edge directions and
    every `angle_step` degrees, and a summed-area table asks whether any
    window of the rectangle's size, either way round, lies wholly
    inside.

This is stage 1 of capacityengine's design (item 324): a building
complying with every zone standard is not also required to fit within
the rectangle, and exclusions for which no layer is supplied (hazards,
heritage, utilities) are not seen, so the result is optimistic.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning)
head(site_shape_factor(sc))
#> [1] site_id          rect_width       rect_depth       developable_area
#> [5] fits             max_lots         decided_by      
#> <0 rows> (or 0-length row.names)
```
