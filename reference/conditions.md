# Conditions under which a rule applies

Attach to any setback (or other rule) with its `when` argument. All the
conditions given must hold. A condition the engine cannot evaluate,
because the layer it needs was not supplied, is not applied, and is
counted and reported with the direction of the error it causes.

## Usage

``` r
conditions(
  min_site_area = NULL,
  max_site_area = NULL,
  rear_sites = NULL,
  corner_sites = NULL,
  within_frontage = NULL,
  beyond_frontage = NULL,
  frontage_depth_share = NULL,
  adjacent_zones = NULL,
  not_adjacent_zones = NULL,
  facing = NULL,
  min_road_width = NULL,
  max_road_width = NULL,
  min_slope = NULL,
  max_slope = NULL,
  distance_to = NULL,
  min_distance = NULL,
  max_distance = NULL
)
```

## Arguments

- min_site_area, max_site_area:

  Site area bounds (m2).

- rear_sites:

  `"include"` (default), `"exclude"` or `"only"`.

- corner_sites:

  `"include"` (default), `"exclude"` or `"only"`.

- within_frontage, beyond_frontage:

  Applies only to boundary segments whose midpoint is within, or beyond,
  this distance (m) of the road frontage.

- frontage_depth_share:

  Applies only beyond this share of site depth from the frontage (e.g.
  Christchurch's "front 60 per cent" exemption is `0.6`).

- adjacent_zones, not_adjacent_zones:

  Zone keys or family names across the boundary that make the rule
  apply, or that stop it applying.

- facing:

  Bearing range `c(from, to)` of the boundary's outward normal (degrees
  clockwise from north) for the rule to apply. A rule for "a site on the
  southern boundary of its neighbour" faces north: `c(315, 45)`.

- min_road_width, max_road_width:

  Road reserve width bounds (m).

- min_slope, max_slope:

  Site slope bounds (per cent).

- distance_to:

  Name of a layer, with `min_distance` / `max_distance`, for rules that
  apply within a distance of a feature (e.g. a station).

- min_distance, max_distance:

  Distance bounds (m) to `distance_to`.

## Value

A list with class `plancap_conditions`.

## Examples

``` r
conditions(adjacent_zones = "RES_ANY", min_site_area = 1000)
#> $min_site_area
#> [1] 1000
#> 
#> $adjacent_zones
#> [1] "RES_ANY"
#> 
#> attr(,"class")
#> [1] "plancap_conditions"
conditions(distance_to = "transit", max_distance = 800)
#> $distance_to
#> [1] "transit"
#> 
#> $max_distance
#> [1] 800
#> 
#> attr(,"class")
#> [1] "plancap_conditions"
```
