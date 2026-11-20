# Boundary classes

The classes a boundary segment can be given by the morphology helpers,
and that setback rules key off. A rulebook may add its own classes for
boundaries identified from a layer (e.g. `"rail"`).

## Usage

``` r
boundary_classes()
```

## Value

Character vector.

## Examples

``` r
boundary_classes()
#>  [1] "road"     "side"     "rear"     "internal" "common"   "coastal" 
#>  [7] "riparian" "lakeside" "reserve"  "rail"    
```
