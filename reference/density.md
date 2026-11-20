# Density rules

Rules that limit the number of dwellings directly. Areas in m2.

## Usage

``` r
density(
  site_area_per_dwelling = NULL,
  dwellings_per_ha = NULL,
  min_site_area = NULL,
  vacant_site_min_area = NULL,
  max_dwellings_per_site = NULL,
  minor_dwellings_per_site = NULL,
  min_dwelling_size = NULL,
  large_site = NULL,
  access_width = NULL,
  source = NULL
)
```

## Arguments

- site_area_per_dwelling:

  Net site area required per dwelling.

- dwellings_per_ha:

  Dwellings per hectare (an alternative statement).

- min_site_area:

  Minimum site area for development.

- vacant_site_min_area:

  Minimum area of a vacant site created by subdivision.

- max_dwellings_per_site:

  Cap on dwellings on one site.

- minor_dwellings_per_site:

  Additional minor (accessory) dwellings.

- min_dwelling_size:

  Minimum dwelling floor area.

- large_site:

  Large-site rules, a list with `area_per_dwelling`, `min_area` and
  optionally `max_average_area`.

- access_width:

  A data frame with `min`, `max` and `max_dwellings`: frontage or access
  width (m) to the most dwellings it may serve. A missing `max` is the
  open top band; a missing `max_dwellings` is no cap.

- source:

  Citation.

## Value

A list with class `plancap_density`.

## Examples

``` r
density(site_area_per_dwelling = 400, minor_dwellings_per_site = 1,
        source = "LLRZ-S1")
#> $site_area_per_dwelling
#> [1] 400
#> 
#> $minor_dwellings_per_site
#> [1] 1
#> 
#> $source
#> [1] "LLRZ-S1"
#> 
#> attr(,"class")
#> [1] "plancap_density"
```
