# Building form limits

Limits on the shape and size of buildings that are not setbacks or site
ratios. Areas in m2, lengths in m.

## Usage

``` r
building_form(
  max_floorplate = NULL,
  min_floorplate = NULL,
  max_tower_floorplate = NULL,
  tower_above_height = NULL,
  tower_above_storey = NULL,
  max_tower_dimension = NULL,
  tower_separation = NULL,
  max_building_length = NULL,
  building_separation = NULL,
  max_building_depth = NULL,
  min_building_width = NULL,
  site_shape = NULL,
  max_site_floorspace = NULL,
  source = NULL
)
```

## Arguments

- max_floorplate:

  Maximum floor area of any storey.

- min_floorplate:

  Smallest storey worth building; smaller storeys end the stack. Default
  from the rulebook defaults.

- max_tower_floorplate, tower_above_height, tower_above_storey:

  Tower floorplate limit and where the tower starts.

- max_tower_dimension:

  Maximum plan dimension of a tower.

- tower_separation:

  Minimum distance between towers.

- max_building_length:

  Maximum length of a building elevation.

- building_separation:

  Minimum distance between buildings on a site: a number or
  [`bands()`](https://faceteconomics.github.io/plancap/reference/bands.md)
  by height.

- max_building_depth:

  Maximum building depth (e.g. 18 m for apartments).

- min_building_width:

  Minimum building width.

- site_shape:

  A length-2 vector `c(width, depth)`: a rectangle that must fit on the
  site for it to be developable.

- max_site_floorspace:

  Maximum floor area on one site.

- source:

  Citation.

## Value

A list with class `plancap_form`.

## Examples

``` r
building_form(max_building_length = 20, building_separation = 10,
              source = "HRZ-S15, HRZ-S16")
#> $max_building_length
#> [1] 20
#> 
#> $building_separation
#> [1] 10
#> 
#> $source
#> [1] "HRZ-S15, HRZ-S16"
#> 
#> attr(,"class")
#> [1] "plancap_form"
```
