# A zone family that depends on the size of the land across a boundary

Some rules apply next to a zone only where that zone's land is large or
small: a recession plane against open space of less than 2,000 m2, an
exemption next to a reserve over 2,000 m2. A family made with
`zone_family()` counts across a boundary only where the contiguous area
of its zones there (every touching polygon of those zones, dissolved) is
within the bounds.

## Usage

``` r
zone_family(zones, min_area = NULL, max_area = NULL, source = NULL)
```

## Arguments

- zones:

  Zone keys in the family.

- min_area, max_area:

  Bounds on the contiguous area (m2): at least `min_area`, less than
  `max_area`.

- source:

  Citation.

## Value

A list with class `plancap_zone_family`, for
[`set_zone_families()`](https://faceteconomics.github.io/plancap/reference/set_rules.md).

## Examples

``` r
rb <- rulebook("Example") |>
  add_zone(zone("OS", method = "none")) |>
  set_zone_families(SMALL_OPEN_SPACE = zone_family("OS", max_area = 2000))
rb$zone_families
#> $SMALL_OPEN_SPACE
#> $SMALL_OPEN_SPACE$zones
#> [1] "OS"
#> 
#> $SMALL_OPEN_SPACE$max_area
#> [1] 2000
#> 
#> 
```
