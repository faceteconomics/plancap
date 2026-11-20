# Height limit

Height limit

## Usage

``` r
height_limit(
  value = NULL,
  occupiable = NULL,
  roof_allowance = NULL,
  storeys = NULL,
  from_overlay = NULL,
  datum = "ground",
  no_limit = FALSE,
  source = NULL
)
```

## Arguments

- value:

  Maximum height (m) above the datum, including any roof allowance.

- occupiable:

  Height (m) up to which floors may be built. Defaults to
  `value - roof_allowance`.

- roof_allowance:

  Extra height (m) allowed for a roof form only, which yields no floor
  space.

- storeys:

  The storey count the plan intends; storey height is taken as
  `occupiable / storeys` where given.

- from_overlay:

  Name of an overlay that supplies the height where the zone states none
  (e.g. a height control map).

- datum:

  What height is measured from: `"ground"` (existing ground, the
  default), `"finished"`, `"average"` (average ground level), `"road"`
  or `"sea_level"` (an absolute level).

- no_limit:

  `TRUE` if the plan sets no height limit; the rulebook's
  `no_limit_height` stand-in is used and results are flagged.

- source:

  Citation.

## Value

A list with class `plancap_height`.

## Examples

``` r
height_limit(12, occupiable = 11, storeys = 3, source = "MRZ-S2")
#> $value
#> [1] 12
#> 
#> $occupiable
#> [1] 11
#> 
#> $storeys
#> [1] 3
#> 
#> $source
#> [1] "MRZ-S2"
#> 
#> attr(,"class")
#> [1] "plancap_height"
height_limit(from_overlay = "height_control", source = "MCZ-S1")
#> $from_overlay
#> [1] "height_control"
#> 
#> $source
#> [1] "MCZ-S1"
#> 
#> attr(,"class")
#> [1] "plancap_height"
```
