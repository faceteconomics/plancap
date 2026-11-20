# Overlays: spatial layers that change the rules

An overlay is a map layer that changes what the zone allows wherever it
applies. The spatial data is supplied at run time under the overlay's
`layer` name; the rulebook holds only what the overlay does.

## Usage

``` r
overlay(
  id,
  type = c("height", "height_surface", "exclusion", "parameters", "flag"),
  layer,
  combine = NULL,
  value = NULL,
  value_field = NULL,
  value_map = NULL,
  floor_value = NULL,
  filter = NULL,
  removes = NULL,
  buffer = NULL,
  applies_to_zones = NULL,
  parameters = NULL,
  additions = NULL,
  enabled = TRUE,
  precedence = 0,
  label = NULL,
  source = NULL,
  notes = NULL
)
```

## Arguments

- id:

  Identifier.

- type:

  What the overlay does:

  - `"height"`: a height limit, a fixed `value` or read from
    `value_field` (optionally through `value_map`);

  - `"height_surface"`: a raster surface of maximum height (airport
    surfaces, viewshafts, sunlight planes);

  - `"exclusion"`: land under the overlay is taken out of the buildable
    area (hazards, designations, tree protection);

  - `"parameters"`: replaces or adjusts named zone parameters, given as
    [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md);

  - `"flag"`: tags the site and changes nothing.

- layer:

  Name of the layer supplied at run time.

- combine:

  How the overlay's value combines with the zone's (see *Combining
  rules* below). Defaults: `"cap"` for heights, `"replace"` for
  parameters.

- value, value_field, value_map:

  Fixed value, or the attribute holding it, or a named list mapping
  attribute codes to values.

- floor_value:

  A height always allowed regardless of the surface, so the effective
  height is `max(surface, floor_value)`.

- filter:

  Named list: attribute to accepted values, applied when the layer is
  read.

- removes:

  For exclusions: `"all"` (every building) or `"residential"` (dwellings
  only).

- buffer:

  For exclusions: distance (m) to buffer the features by, or the name of
  an attribute holding it (e.g. a tree protection radius).

- applies_to_zones:

  Zone keys the overlay applies in; `NULL` for all.

- parameters:

  For `type = "parameters"`: a
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md).

- additions:

  A
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  whose setbacks are added to the zone's own instead of replacing them
  (e.g. an extra yard).

- enabled:

  Whether a run uses the overlay unless told otherwise.

- precedence:

  Tie-break between overlays: higher wins.

- label, source, notes:

  Description and citation.

## Value

A list with class `plancap_overlay`.

## Combining rules

Every applicable rule produces a limit, and each declares how its limit
combines with the others:

- `"cap"`: the most restrictive wins (the default for limits);

- `"replace"`: replaces the zone's value even if more permissive;

- `"floor"`: a minimum entitlement that cannot be taken away;

- `"add"` / `"multiply"`: bonuses and percentage adjustments.

Evaluation order is fixed: zone, then areas (precincts), then overlays,
then bonuses, then entitlements.

## See also

[`add_overlay()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)

## Examples

``` r
overlay("height_control", "height", layer = "height_areas",
        value_field = "max_height_m", combine = "replace",
        source = "Planning maps, height control")
#> $type
#> [1] "height"
#> 
#> $layer
#> [1] "height_areas"
#> 
#> $combine
#> [1] "replace"
#> 
#> $value_field
#> [1] "max_height_m"
#> 
#> $enabled
#> [1] TRUE
#> 
#> $precedence
#> [1] 0
#> 
#> $source
#> [1] "Planning maps, height control"
#> 
#> attr(,"id")
#> [1] "height_control"
#> attr(,"class")
#> [1] "plancap_overlay"
overlay("flood", "exclusion", layer = "flood_hazard", source = "Rule 9.2")
#> $type
#> [1] "exclusion"
#> 
#> $layer
#> [1] "flood_hazard"
#> 
#> $removes
#> [1] "all"
#> 
#> $enabled
#> [1] TRUE
#> 
#> $precedence
#> [1] 0
#> 
#> $source
#> [1] "Rule 9.2"
#> 
#> attr(,"id")
#> [1] "flood"
#> attr(,"class")
#> [1] "plancap_overlay"
```
