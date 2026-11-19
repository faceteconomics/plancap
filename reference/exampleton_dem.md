# Exampleton ground surface

A 5 m digital elevation model of
[`exampleton()`](https://faceteconomics.github.io/plancap/reference/exampleton.md):
a gentle rise to the north, a hill in the north-east steep enough to
trigger slope rules (above 15 per cent), and a shallow river valley in
the south.

## Usage

``` r
exampleton_dem()
```

## Value

A
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
of ground level in metres.

## Examples

``` r
dem <- exampleton_dem()
dem
#> class       : SpatRaster
#> size        : 190, 330, 1  (nrow, ncol, nlyr)
#> resolution  : 5, 5  (x, y)
#> extent      : 2200000, 2201650, 5600000, 5600950  (xmin, xmax, ymin, ymax)
#> coord. ref. : NZGD2000 / New Zealand Transverse Mercator 2000 (EPSG:2193)
#> source      : exampleton_dem.tif
#> name        :  ground_m
#> min value   :       2.3
#> max value   : 51.439999
```
