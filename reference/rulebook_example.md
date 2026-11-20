# Rulebooks shipped with plancap

plancap ships the Exampleton rulebook (for the synthetic town from
[`exampleton()`](https://faceteconomics.github.io/plancap/reference/exampleton.md))
and, as dated worked examples, rulebooks for three New Zealand councils:
Auckland (Auckland Unitary Plan, operative), Christchurch and
Wellington. The council rulebooks were converted from the capacityengine
project and carry every rule citation; check the plan itself before
relying on any value.

## Usage

``` r
rulebook_example(name = "exampleton", validate = FALSE)

rulebook_examples()

rulebook_example_path(name = "exampleton")
```

## Arguments

- name:

  Name of a shipped rulebook; see `rulebook_examples()`.

- validate:

  Whether to validate on reading (the council rulebooks give warnings
  for values whose citation was not recorded).

## Value

`rulebook_example()` returns a `plancap_rulebook`; `rulebook_examples()`
the available names; `rulebook_example_path()` the file path.

## Examples

``` r
rulebook_examples()
#> [1] "auckland"     "christchurch" "exampleton"   "wellington"  
rb <- rulebook_example("exampleton")
rb
#> <plancap rulebook> Exampleton District Plan
#> exampleton-dp-2026 | Exampleton | NZ | as at 2026-01-01
#> 7 zones, 4 overlays, 1 area, 2 bonuses, 1 entitlement; 3 unmodelled rules.
#> Units: metres.
#>  zone label                      method     height           setbacks coverage
#>  LDR  Low Density Residential    hybrid     8                5        0.35    
#>  MDR  Medium Density Residential volumetric 12               5        0.5     
#>  HDR  High Density Residential   volumetric 22               6        0.6     
#>  MU   Mixed Use                  volumetric <centre_heights> 1                
#>  TC   Town Centre                volumetric <centre_heights> 2                
#>  IND  Industrial                 volumetric 15               2        0.8     
#>  OS   Open Space                 none                        0                
#>  codes
#>  LDR  
#>  MDR  
#>  HDR  
#>  MU   
#>  TC   
#>  IND  
#>  OS   
head(rule_table(rb))
#>   scope  id zone         rule        value applies_to conditions variant
#> 1  zone LDR  LDR       method       hybrid       <NA>       <NA>    <NA>
#> 2  zone LDR  LDR       height 8; 2 storeys       <NA>       <NA>    <NA>
#> 3  zone LDR  LDR setback:yard          4 m       road       <NA>    <NA>
#> 4  zone LDR  LDR setback:yard        1.5 m       side       <NA>    <NA>
#> 5  zone LDR  LDR setback:yard          3 m       rear       <NA>    <NA>
#> 6  zone LDR  LDR setback:yard         20 m   riparian       <NA>    <NA>
#>                                       source
#> 1                                       <NA>
#> 2                                 EDP LDR-S1
#> 3                                 EDP LDR-S3
#> 4                                 EDP LDR-S3
#> 5                                 EDP LDR-S3
#> 6 EDP NATC-S1: 20 m from the bank of a river
```
