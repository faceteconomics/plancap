# A share of site area

Wraps a coverage, landscaping, impervious or floor area ratio rule with
its citation.

## Usage

``` r
ratio(value, source = NULL)
```

## Arguments

- value:

  A number (a share, so between 0 and 1 for coverage-type rules), a
  formula string, or
  [`bands()`](https://faceteconomics.github.io/plancap/reference/bands.md).

- source:

  Citation.

## Value

A list with class `plancap_ratio`.

## Examples

``` r
ratio(0.5, source = "Rule 4.3.2")
#> $value
#> [1] 0.5
#> 
#> $source
#> [1] "Rule 4.3.2"
#> 
#> attr(,"class")
#> [1] "plancap_ratio"
ratio(bands("site_area", c(500, Inf), c(0.5, 0.4)), source = "Table 5")
#> $bands
#> $bands$by
#> [1] "site_area"
#> 
#> $bands$bands
#> $bands$bands[[1]]
#> $bands$bands[[1]]$min
#> [1] 0
#> 
#> $bands$bands[[1]]$max
#> [1] 500
#> 
#> $bands$bands[[1]]$value
#> [1] 0.5
#> 
#> 
#> $bands$bands[[2]]
#> $bands$bands[[2]]$min
#> [1] 500
#> 
#> $bands$bands[[2]]$value
#> [1] 0.4
#> 
#> 
#> 
#> 
#> $source
#> [1] "Table 5"
#> 
#> attr(,"class")
#> [1] "plancap_ratio"
```
