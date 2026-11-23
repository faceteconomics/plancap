# A capacity dashboard

Four plots of a capacity result on one page: floor area by zone, by
storey, the constraint waterfall and a map. Needs the patchwork package.

## Usage

``` r
# S3 method for class 'plancap_capacity'
autoplot(object, grid = NULL, mode = "light", ...)
```

## Arguments

- object:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- grid:

  Cell size (m) for the map; default about a twentieth of the extent.

- mode:

  `"light"` or `"dark"`.

- ...:

  Unused.

## Value

A patchwork object.
