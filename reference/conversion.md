# Floor area to dwellings conversion

Dwellings are a derived view of floor area. Give either one average
dwelling size or a unit mix.

## Usage

``` r
conversion(
  dwelling_size = NULL,
  unit_mix = NULL,
  efficiency = 1,
  min_one_dwelling = TRUE,
  min_one_dwelling_floor = NULL,
  source = NULL
)
```

## Arguments

- dwelling_size:

  Average gross floor area per dwelling (m2), including its share of
  circulation.

- unit_mix:

  A data frame with `name`, `size` (m2) and `share` (summing to 1).

- efficiency:

  Share of gross floor area that is saleable or lettable, applied before
  dividing by dwelling size. 1 if `dwelling_size` is already a gross
  figure.

- min_one_dwelling:

  If `TRUE`, a site enabling residential floor area of at least
  `min_one_dwelling_floor` (or, if that is not set, the zone's minimum
  dwelling size) yields at least one dwelling.

- min_one_dwelling_floor:

  Residential floor area (m2) at or above which a site counts at least
  one dwelling.

- source:

  Citation or reasoning for the assumption.

## Value

A list with class `plancap_conversion`.

## Examples

``` r
conversion(dwelling_size = 100, source = "Assumed average")
#> $dwelling_size
#> [1] 100
#> 
#> $efficiency
#> [1] 1
#> 
#> $min_one_dwelling
#> [1] TRUE
#> 
#> $source
#> [1] "Assumed average"
#> 
#> attr(,"class")
#> [1] "plancap_conversion"
conversion(unit_mix = data.frame(name = c("1br", "2br", "3br"),
                                 size = c(50, 75, 100),
                                 share = c(0.3, 0.5, 0.2)),
           efficiency = 0.85)
#> $unit_mix
#> $unit_mix[[1]]
#> $unit_mix[[1]]$name
#> [1] "1br"
#> 
#> $unit_mix[[1]]$size
#> [1] 50
#> 
#> $unit_mix[[1]]$share
#> [1] 0.3
#> 
#> 
#> $unit_mix[[2]]
#> $unit_mix[[2]]$name
#> [1] "2br"
#> 
#> $unit_mix[[2]]$size
#> [1] 75
#> 
#> $unit_mix[[2]]$share
#> [1] 0.5
#> 
#> 
#> $unit_mix[[3]]
#> $unit_mix[[3]]$name
#> [1] "3br"
#> 
#> $unit_mix[[3]]$size
#> [1] 100
#> 
#> $unit_mix[[3]]$share
#> [1] 0.2
#> 
#> 
#> 
#> $efficiency
#> [1] 0.85
#> 
#> $min_one_dwelling
#> [1] TRUE
#> 
#> attr(,"class")
#> [1] "plancap_conversion"
```
