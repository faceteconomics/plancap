# Getting started

plancap estimates the floor area and dwellings that planning rules
enable on each parcel of land. You give it three things:

1.  a **rulebook**: every zone, overlay and precinct rule, each with its
    citation;
2.  the **parcels**, with the roads around them;
3.  the **maps** the rules refer to: zoning, and any overlay or area
    layers.

It returns, for every site, the stack of storeys the rules allow, its
floor area and the dwellings that floor area holds, with the rule that
limited each. This vignette runs the whole chain on Exampleton, a
synthetic town that ships with the package.

``` r

library(plancap)
#> 
#> Attaching package: 'plancap'
#> The following object is masked from 'package:stats':
#> 
#>     density
```

## The town and its plan

``` r

town <- exampleton()
names(town)
#>  [1] "parcels"          "road_centrelines" "zoning"           "height_areas"    
#>  [5] "flood_hazard"     "heritage"         "precincts"        "water"           
#>  [9] "transit"          "trees"            "buildings"
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
```

[`rule_table()`](https://faceteconomics.github.io/plancap/reference/rule_table.md)
lists every rule with its source:

``` r

head(rule_table(rb)[, c("zone", "rule", "value", "source")], 8)
#>   zone          rule             value
#> 1  LDR        method            hybrid
#> 2  LDR        height      8; 2 storeys
#> 3  LDR  setback:yard               4 m
#> 4  LDR  setback:yard             1.5 m
#> 5  LDR  setback:yard               3 m
#> 6  LDR  setback:yard              20 m
#> 7  LDR setback:plane 45 deg from 2.5 m
#> 8  LDR  coverage_max              0.35
#>                                       source
#> 1                                       <NA>
#> 2                                 EDP LDR-S1
#> 3                                 EDP LDR-S3
#> 4                                 EDP LDR-S3
#> 5                                 EDP LDR-S3
#> 6 EDP NATC-S1: 20 m from the bank of a river
#> 7                                 EDP LDR-S2
#> 8                                 EDP LDR-S4
```

## A scenario

A **scenario** is everything that determines capacity: the rulebook, the
parcels, roads and water, the zoning, and the layers the rulebook’s
overlays and areas refer to.

``` r

sc <- scenario("Operative", rb,
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning,
               layers = town[c("height_areas", "flood_hazard", "heritage", "trees",
                               "precincts", "transit")],
               water = town$water, centrelines = town$road_centrelines)
sc
#> <plancap scenario> Operative
#> Rulebook: Exampleton District Plan; 1377 parcels; 7 zoning features; layers:
#> height_areas, flood_hazard, heritage, trees, precincts, transit.
```

## Capacity

``` r

cap <- estimate_capacity(sc)
cap
#> <plancap capacity> Operative: 1379 sites, 2,026,327 m2 floor area (1,622,053 m2
#> residential), 16,197 dwellings (+102 minor).
#> Plan-enabled, gross, blank-slate capacity; dwellings at 78 m2 and 85%
#> efficiency.
#> Paths: hybrid_density 108, volumetric 1271.
#> With bonuses: +394 dwellings.
summary(cap)
#> 
#> ── Capacity: Operative ──
#> 
#> 1,379 sites on 106.4 ha: 2,026,327 m2 of floor area (1,622,053 m2 residential,
#> 404,275 m2 business), 16,197 dwellings and 102 minor dwellings.
#> Plan-enabled, gross, blank-slate capacity; dwellings at 78 m2 and 85%
#> efficiency.
#> 
#> ── By zone
#>  zone_key sites land_area floor_area dwellings  far floor_area_share
#>       HDR   272   215,500    510,439     5,225 2.37            25.2%
#>       IND    24    48,000     97,673         0 2.03             4.8%
#>       LDR   108    96,000     64,707       102 0.67             3.2%
#>       MDR   714   512,500    714,195     7,397 1.39            35.2%
#>        MU   176   128,000    383,313     2,131 2.99            18.9%
#>        TC    85    64,000    256,000     1,342 4.00            12.6%
#> 
#> ── Flags
#> no_capacity 8, ok 1,371
#> 
#> ── What limits dwellings
#> floor_area 1,246, density 108, area_total 19, entitlement 6
```

## Checking the result

[`check_capacity()`](https://faceteconomics.github.io/plancap/reference/check_capacity.md)
reconciles the run: every parcel accounted for, land in equal to land
out, floor area by storey adding to floor area by site, and any warnings
from the engine.

``` r

check_capacity(cap)
#> ✔ parcels accounted for: 1377 of 1377 (every input parcel is in a site)
#> ✔ land in equals land out: 1064000 of 1064000 m2 (site areas add to parcel areas (overlaps aside))
#> ✔ storeys add to sites: 2026327 m2 (floor area by storey equals floor area by site)
#> ✔ uses add to floor area:  (residential plus business equals floor area)
#> ✔ no missing or negative values: 0 (floor area and dwellings)
#> ✔ within the height's storeys: 0 (no site above its area times its storeys)
#> ✔ site ids unique: 0
#> ✔ dwellings need floor area: 0 (volumetric sites with dwellings but no floor area)
#> ✔ access measured: 0 (sites the access width table could not be applied to)
#> ✔ flags: no_capacity 8, ok 1371 (sites by flag)
#> ✔ sites with no capacity: 8 (no_capacity 8)
```

## Why a site has what it has

[`explain_site()`](https://faceteconomics.github.io/plancap/reference/explain_site.md)
gives the account for one site: the rules that apply, each boundary with
the setback set at each storey and its citation, and what bound each
storey.

``` r

explain_site(cap, "P00001")
#> 
#> ── Site P00001 (Operative) ──
#> 
#> MDR; 714.3 m2; floor area 609.6 m2 in 3 storeys (height allows 3); 6 dwellings
#> by the volumetric path.
#> 
#> ── Rules
#> zone: MDR
#> overlay: flood exclusion (57% of site) [EDP NH-R4: new buildings in the flood
#> plain are non-complying]
#> 
#> ── Boundaries
#>   segment class length across
#>  P00001-1  road   50.0   <NA>
#>  P00001-2  road   14.3    MDR
#>  P00001-3  rear   50.0    MDR
#>  P00001-4  side   14.3     OS
#> 
#> ── Setbacks at the ground storey
#>   segment class setback rule     source
#>  P00001-1  road     2.5 yard EDP MDR-S3
#>  P00001-2  road     2.5 yard EDP MDR-S3
#>  P00001-3  rear     1.0 yard EDP MDR-S3
#>  P00001-4  side     1.0 yard EDP MDR-S3
#> 
#> ── Storeys
#>  storey ceiling buildable enabled limited_by
#>       1    3.67     203.2   203.2   geometry
#>       2    7.33     203.2   203.2   geometry
#>       3   11.00     203.2   203.2   geometry
#> 
#> ── Dwellings
#> 6 by the volumetric path, limited by floor_area; access 64.29 m (frontage).
#> Plan-enabled, gross, blank-slate capacity; dwellings at 78 m2 and 85%
#> efficiency.
```

## Next

- *Summaries*
  ([`vignette("summaries", package = "plancap")`](https://faceteconomics.github.io/plancap/articles/summaries.md)):
  capacity by zone, height, site size, location and binding constraint,
  the constraint breakdown, and sweeping a rule with
  [`sensitivity()`](https://faceteconomics.github.io/plancap/reference/sensitivity.md).
- Plan changes are compared as scenarios:
  [`scenario_change()`](https://faceteconomics.github.io/plancap/reference/scenario.md)
  describes a change from a base scenario.
