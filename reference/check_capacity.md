# Reconciliation and diagnostics for a capacity result

Checks that nothing was lost or double counted and lists anything that
looks wrong: every parcel accounted for, land in equal to land out,
floor area by storey adding to floor area by site, no missing or
negative values, no site above what its height allows, and a tally of
sites with no capacity by reason.

## Usage

``` r
check_capacity(cap)
```

## Arguments

- cap:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

## Value

A data frame of class `plancap_checks`: `check`, `status` (`"ok"`,
`"warn"` or `"fail"`), `value` and `detail`.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
check_capacity(estimate_capacity(sc))
#> ✔ parcels accounted for: 1377 of 1377 (every input parcel is in a site)
#> ✔ land in equals land out: 1064000 of 1064000 m2 (site areas add to parcel areas (overlaps aside))
#> ✔ storeys add to sites: 2087343 m2 (floor area by storey equals floor area by site)
#> ✔ uses add to floor area:  (residential plus business equals floor area)
#> ✔ no missing or negative values: 0 (floor area and dwellings)
#> ✔ within the height's storeys: 0 (no site above its area times its storeys)
#> ✔ site ids unique: 0
#> ✔ dwellings need floor area: 0 (volumetric sites with dwellings but no floor area)
#> ✔ access measured: 0 (sites the access width table could not be applied to)
#> ✔ flags: ok 1379 (sites by flag)
```
