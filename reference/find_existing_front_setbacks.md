# The existing front setback of the dwellings along a street

Some plans set a front yard by what is already there rather than by a
number: the Auckland Unitary Plan's Special Character Areas set it as
"the average of existing setbacks of dwellings on adjacent sites, being
the three sites on either side of the subject site or six sites on one
side" (D18.6.1.3.1). A yard declared
`yard(value_from = "existing_front_setback")` takes its depth from this
measurement, per road boundary.

## Usage

``` r
find_existing_front_setbacks(
  sites,
  roads,
  buildings,
  streets,
  street_field = "name",
  neighbours = NULL,
  site_ids = NULL,
  rulebook = NULL,
  morphology = list()
)
```

## Arguments

- sites:

  Sites, `sf` polygons with a `site_id` column.

- roads:

  Road parcels.

- buildings:

  Building outlines (polygons).

- streets:

  Street centre lines with a name column (`street_field`).

- street_field:

  Column of `streets` holding the street name.

- neighbours:

  Optional further parcels that may be neighbours (outside the sites
  studied, so a site at the edge sees across it).

- site_ids:

  Sites to measure. Default all.

- rulebook, morphology:

  Morphology settings, as for
  [morphology](https://faceteconomics.github.io/plancap/reference/morphology.md).

## Value

A data frame, one row per road boundary segment measured: `segment_id`,
`site_id`, `street`, `setback` (`NA` where nothing was measured), `n`
(dwellings averaged) and `neighbours` (their ids and setbacks, as
`"id:metres"` joined by `";"`).

## Details

For each road boundary of a site:

1.  **The street** is the named street line nearest the boundary's
    middle, merged along its length (every line sharing its name), and
    its **corridor** is the road parcels that line runs through.

2.  **The adjacent sites** are the parcels with at least
    `rear_site_max_frontage` of boundary on that corridor, on the same
    side of the street, ordered by where each meets it:
    `front_setback_neighbours` on each side, or twice that on one side
    where the other has fewer (a street end or a corner). A rear site or
    a sliver is not beside the subject along the street and is not
    counted.

3.  **A dwelling's setback** is the distance to the corridor of the
    front-most building on the parcel with at least
    `front_setback_min_dwelling_area` of it inside the parcel, so a
    garage or shed is not taken for a dwelling. A neighbour with none
    adds nothing and is not replaced, because the plan names which
    sites.

4.  **The yard** is the mean of the setbacks found; `NA` where none is.

A corner site gets a yard on each street from that street's neighbours.
Building outlines traced from imagery include verandas and porches where
the trace does, which a plan's "setback of dwellings" may not settle.
This follows capacityengine (items 314, 317 and 325).
