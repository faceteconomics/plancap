# Colours of the plancap palette

Colours of the plancap palette

## Usage

``` r
capacity_palette(
  type = c("categorical", "sequential", "diverging", "ink"),
  n = NULL,
  mode = c("light", "dark")
)
```

## Arguments

- type:

  `"categorical"`, `"sequential"`, `"diverging"` or `"ink"`.

- n:

  For categorical, how many slots (at most 8); for sequential, how many
  steps.

- mode:

  `"light"` or `"dark"`.

## Value

A character vector of hex colours (`"ink"`: a named list).

## Examples

``` r
capacity_palette("categorical", 4)
#> [1] "#2a78d6" "#eb6834" "#1baf7a" "#eda100"
capacity_palette("sequential", 5, mode = "dark")
#> [1] "#0D366B" "#1C5CAB" "#3987E5" "#86B6EF" "#CDE2FB"
```
