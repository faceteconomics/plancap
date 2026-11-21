# Measure the legal access to rear sites

Access width tables (a density rule's `access_width`) limit the
dwellings a site may have by the width of its access. A site with road
frontage is measured by its frontage. A rear site (less frontage than
`rear_site_max_frontage`, see
[`morphology_defaults()`](https://faceteconomics.github.io/plancap/reference/morphology_defaults.md))
is usually reached another way, and is measured here, following
capacityengine (item 259):

## Usage

``` r
find_access_widths(
  sites,
  roads,
  easements = NULL,
  other_parcels = NULL,
  rulebook = NULL,
  morphology = list()
)
```

## Arguments

- sites:

  Sites, `sf` polygons with a `site_id` column.

- roads:

  Road parcels.

- easements:

  Optional easement areas.

- other_parcels:

  Optional other parcels (not roads), for access lots.

- rulebook, morphology:

  Morphology settings, as for
  [morphology](https://faceteconomics.github.io/plancap/reference/morphology.md).

## Value

A data frame: `site_id`, `frontage`, `is_rear`, `contact` (the entrance
strip), `easement_width`, `access_lot_width`, `access_width` and
`access_method` (`"frontage"`, `"entrance_strip"`, `"easement"`,
`"access_lot"`, `"combination"`, `"sibling"` or `"none"`).

## Details

1.  **Its own entrance strip**: the longest stretch of its boundary on a
    road parcel, which reads a pan-handle's driveway more truly than the
    classified road segments do.

2.  **Easements** (`easements`, such as LINZ non-primary parcels of
    intent "Easement"): touching easement areas are dissolved into
    networks, because one right of way is often several surveyed areas
    of which one meets the road; a network's width is its longest
    stretch of road contact.

3.  **Access lots** (`other_parcels`, the other primary parcels): a
    parcel outside every site, smaller than `access_lot_max_area`, and
    strip-width where it meets the road; a jointly owned access lot can
    only be recognised by shape.

Road contact wider than `access_max_strip_width` is a lot, not a strip,
and is ignored. Widths add only where a strip lies over adjoining land;
an easement over the site's own driveway is the same access counted
twice and combines by the larger. Pieces of one site split by a zone
boundary take the best access of any piece. A site where nothing is
found has no measurable access (`NA`): the access width table does not
apply to it and it is flagged, because titled land has legal access
somewhere, often by a right of way that predates digital survey.

Easement layers rarely record what an easement is for, so a drainage
easement running to the street passes as a right of way: the measurement
can overstate.

## Examples

``` r
town <- exampleton()
land <- town$parcels[town$parcels$parcel_type == "land", ]
names(land)[names(land) == "parcel_id"] <- "site_id"
acc <- find_access_widths(land, town$parcels[town$parcels$parcel_type == "road", ])
table(acc$access_method)
#> 
#> frontage 
#>     1377 
```
