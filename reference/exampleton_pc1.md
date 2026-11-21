# Exampleton Plan Change 1

The worked plan change for Exampleton, built to exercise every kind of
difference between two scenarios (see
[`compare_scenarios()`](https://faceteconomics.github.io/plancap/reference/compare_scenarios.md)):

## Usage

``` r
exampleton_pc1()
```

## Value

A list: `rulebook`, and `sf` layers `zoning`, `flood_hazard` and
`parcels` (all parcels, with the re-subdivided block's new lots).

## Details

- a rulebook that `extends:` the operative one: MDR's height from 12 m
  to 16 m, and a new Terraced Housing zone (THZ);

- a zoning layer rezoning the MDR blocks whose centre is within 600 m of
  the station to THZ;

- a wider flood plain (70 m either side of the stream, from 45 m);

- one low density block re-subdivided into new lots.

## Examples

``` r
pc1 <- exampleton_pc1()
pc1$rulebook
#> <plancap rulebook> Exampleton District Plan, Plan Change 1 (as notified)
#> exampleton-pc1-2026 | Exampleton | NZ | as at 2026-09-01
#> 8 zones, 4 overlays, 1 area, 2 bonuses, 1 entitlement; 3 unmodelled rules.
#> Units: metres.
#>  zone label                      method     height           setbacks coverage
#>  LDR  Low Density Residential    hybrid     8                5        0.35    
#>  MDR  Medium Density Residential volumetric 16               5        0.5     
#>  HDR  High Density Residential   volumetric 22               6        0.6     
#>  MU   Mixed Use                  volumetric <centre_heights> 1                
#>  TC   Town Centre                volumetric <centre_heights> 2                
#>  IND  Industrial                 volumetric 15               2        0.8     
#>  OS   Open Space                 none                        0                
#>  THZ  Terraced Housing           volumetric 14               3        0.6     
#>  codes
#>  LDR  
#>  MDR  
#>  HDR  
#>  MU   
#>  TC   
#>  IND  
#>  OS   
#>  THZ  
table(pc1$zoning$zone)
#> 
#> HDR IND LDR MDR  MU  OS  TC THZ 
#>   1   1   1   1   1   1   1   1 
```
