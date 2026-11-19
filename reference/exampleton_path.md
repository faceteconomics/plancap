# Path to an Exampleton file

Path to an Exampleton file

## Usage

``` r
exampleton_path(file = c("gpkg", "dem"))
```

## Arguments

- file:

  `"gpkg"` for the vector layers, `"dem"` for the ground surface.

## Value

The full path to the file installed with the package.

## Examples

``` r
exampleton_path("gpkg")
#> [1] "/home/runner/work/_temp/Library/plancap/extdata/exampleton.gpkg"
```
