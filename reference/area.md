# Areas: precincts, sub-precincts and site-specific controls

An area is a mapped place with its own rules that *replace* the zone's
(where an overlay usually only caps them). Sub-areas refine the area's
rules for parts of it, keyed by an attribute of the area layer.

## Usage

``` r
area(
  id,
  layer,
  filter = NULL,
  applies_to_zones = NULL,
  parameters = NULL,
  additions = NULL,
  zone_parameters = NULL,
  sub_area_field = NULL,
  sub_areas = NULL,
  max_dwellings = NULL,
  min_dwellings = NULL,
  max_floorspace = NULL,
  combine = "replace",
  label = NULL,
  source = NULL,
  notes = NULL
)
```

## Arguments

- id:

  Identifier.

- layer:

  Name of the layer supplied at run time.

- filter:

  Named list: attribute to accepted values.

- applies_to_zones:

  Zone keys the area changes; `NULL` for all.

- parameters:

  A
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  applied to every zone in the area.

- additions:

  A
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  whose setbacks are added to the zone's own instead of replacing them.

- zone_parameters:

  Named list of
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md),
  by zone key, for changes that differ by zone.

- sub_area_field:

  Attribute of the layer naming the sub-area.

- sub_areas:

  Named list, by sub-area value, of
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  or
  [`sub_area()`](https://faceteconomics.github.io/plancap/reference/sub_area.md).

- max_dwellings, min_dwellings, max_floorspace:

  Totals across the whole area (e.g. a precinct capped at 2,000
  dwellings).

- combine:

  `"replace"` (default) or `"cap"`.

- label, source, notes:

  Description and citation.

## Value

A list with class `plancap_area`.

## See also

[`add_area()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)

## Examples

``` r
area("quarry", layer = "precincts",
     parameters = zone_changes(height = height_limit(16, source = "I1.6.1")),
     sub_area_field = "sub_precinct",
     sub_areas = list(B = zone_changes(height = height_limit(20, source = "I1.6.1(b)"))),
     source = "Quarry Precinct")
#> $layer
#> [1] "precincts"
#> 
#> $combine
#> [1] "replace"
#> 
#> $parameters
#> $parameters$height
#> $parameters$height$value
#> [1] 16
#> 
#> $parameters$height$source
#> [1] "I1.6.1"
#> 
#> 
#> 
#> $sub_area_field
#> [1] "sub_precinct"
#> 
#> $sub_areas
#> $sub_areas$B
#> $sub_areas$B$height
#> $sub_areas$B$height$value
#> [1] 20
#> 
#> $sub_areas$B$height$source
#> [1] "I1.6.1(b)"
#> 
#> 
#> 
#> 
#> $source
#> [1] "Quarry Precinct"
#> 
#> attr(,"id")
#> [1] "quarry"
#> attr(,"class")
#> [1] "plancap_area"
```
