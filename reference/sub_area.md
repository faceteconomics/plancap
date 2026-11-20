# A sub-area of an area

Most sub-areas only change the area's rules, which
[`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
says. Use `sub_area()` when a sub-area also adds setbacks, changes rules
for one zone only, or caps dwellings (alone or shared with other
sub-areas).

## Usage

``` r
sub_area(
  changes = zone_changes(),
  additions = NULL,
  zone_parameters = NULL,
  max_dwellings = NULL,
  min_dwellings = NULL,
  max_floorspace = NULL,
  total_group = NULL
)
```

## Arguments

- changes:

  A
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md).

- additions:

  A
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  whose setbacks are added to the zone's.

- zone_parameters:

  Named list of
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  by zone key.

- max_dwellings, min_dwellings, max_floorspace:

  Totals for the sub-area.

- total_group:

  Sub-areas with the same `total_group` share one total.

## Value

A list with class `plancap_sub_area`.

## Examples

``` r
sub_area(zone_changes(height = height_limit(20, source = "I1.6.1(b)")),
         max_dwellings = 120, total_group = "BCD")
#> $height
#> $height$value
#> [1] 20
#> 
#> $height$source
#> [1] "I1.6.1(b)"
#> 
#> 
#> $totals
#> $totals$max_dwellings
#> [1] 120
#> 
#> 
#> $total_group
#> [1] "BCD"
#> 
#> attr(,"class")
#> [1] "plancap_sub_area"
```
