# Uses a zone enables

Uses a zone enables

## Usage

``` r
use_mix(
  residential = TRUE,
  business = FALSE,
  residential_share = NULL,
  source = NULL
)
```

## Arguments

- residential, business:

  Whether each use is enabled.

- residential_share:

  Share of enabled floor area counted as residential in a zone that
  enables both: a number, or
  [`bands()`](https://faceteconomics.github.io/plancap/reference/bands.md)
  by `"storey"` (e.g. `bands("storey", c(1, Inf), c(0, 1))` for a
  non-residential ground floor).

- source:

  Citation for the share (it is usually an assumption, not a rule, so
  say whose).

## Value

A list with class `plancap_use`.

## Examples

``` r
use_mix(residential = TRUE, business = TRUE, residential_share = 0.4,
        source = "Council split, 2023 HBA")
#> $residential
#> [1] TRUE
#> 
#> $business
#> [1] TRUE
#> 
#> $residential_share
#> [1] 0.4
#> 
#> $source
#> [1] "Council split, 2023 HBA"
#> 
#> attr(,"class")
#> [1] "plancap_use"
```
