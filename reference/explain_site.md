# Explain one site's capacity

Everything behind one site's figures: what it is (zone, area, frontage,
corner or rear), which rules apply (the zone, and the precincts and
overlays that change it), every boundary with the setback applied at
each storey and the rule and citation that set it, the storey stack with
what bound each storey, and how floor area became dwellings.

## Usage

``` r
explain_site(cap, site_id)
```

## Arguments

- cap:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- site_id:

  The site to explain.

## Value

A `plancap_explanation` list: `site` (one row), `rules` (the zone, areas
and overlays that apply, with the key values), `boundaries` (one row per
boundary segment), `setbacks` (one row per boundary and storey),
`storeys` (one row per storey) and `dwellings`. Printing it gives a
readable account.

## Details

The site's envelope is rebuilt with its setbacks kept, on the same
inputs and options as the capacity run.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
cap <- estimate_capacity(sc)
explain_site(cap, cap$sites$site_id[which.max(cap$sites$floor_area)])
#> 
#> ── Site P00700 (Operative) ──
#> 
#> TC; 3,000 m2; floor area 12,000 m2 in 7 storeys (height allows 7); 64 dwellings
#> by the volumetric path.
#> 
#> ── Rules 
#> zone: TC
#> overlay: centre_heights height = 27 (100% of site) [EDP Planning Map H: 27 m in
#> the centre, 18 m in its frame]
#> 
#> ── Boundaries 
#>   segment class length across
#>  P00700-1  road     50     MU
#>  P00700-2  road     60     MU
#>  P00700-3  side     50     TC
#>  P00700-4  rear     60     TC
#> 
#> ── Setbacks at the ground storey 
#>   segment class setback rule source
#>  P00700-1  road       0 <NA>   <NA>
#>  P00700-2  road       0 <NA>   <NA>
#>  P00700-3  side       0 <NA>   <NA>
#>  P00700-4  rear       0 <NA>   <NA>
#> 
#> ── Storeys 
#>  storey ceiling buildable enabled limited_by
#>       1     4.5      3000    3000   geometry
#>       2     8.0      3000    3000   geometry
#>       3    11.5      3000    3000   geometry
#>       4    15.0      3000    3000   geometry
#>       5    18.5      2679       0        far
#>       6    22.0      2679       0        far
#>       7    25.5      2679       0        far
#> 
#> ── Dwellings 
#> 64 by the volumetric path, limited by floor_area; access 110 m (frontage).
#> Plan-enabled, gross, blank-slate capacity; dwellings at 78 m2 and 85%
#> efficiency.
```
