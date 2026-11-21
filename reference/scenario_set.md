# Sets of scenarios, run together

`scenario_set()` collects scenarios to compare; the first is the
baseline. `run_scenarios()` runs them all, the baseline in full and
every other incrementally from it, so a plan change that touches a tenth
of the sites rebuilds about a tenth of them.

## Usage

``` r
scenario_set(...)

run_scenarios(x, ..., progress = TRUE)
```

## Arguments

- ...:

  For `run_scenarios()`: passed to
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- x:

  A scenario set.

- progress:

  Whether to report each run.

## Value

`scenario_set()`: a `plancap_scenario_set`. `run_scenarios()`: a
`plancap_results`, a named list of capacity results with the set.

## See also

[`compare_scenarios()`](https://faceteconomics.github.io/plancap/reference/compare_scenarios.md),
[`read_scenarios()`](https://faceteconomics.github.io/plancap/reference/read_scenarios.md)

## Examples

``` r
town <- exampleton()
pc1 <- exampleton_pc1()
base <- scenario("Operative", rulebook_example("exampleton"),
                 parcels = town$parcels[town$parcels$parcel_type == "land", ],
                 roads = town$parcels[town$parcels$parcel_type == "road", ],
                 zoning = town$zoning, layers = town[c("height_areas", "flood_hazard", "transit")])
change <- scenario_change(base, "PC1", rulebook = pc1$rulebook, zoning = pc1$zoning)
res <- run_scenarios(scenario_set(base, change))
#> Operative: 5.7 s.
#> PC1: 4.6 s, 575 sites copied from the baseline.
res
#> <plancap results> 2 scenarios
#>   scenario sites land_area floor_area residential_floor_area dwellings
#>  Operative 1,379 1,064,000  2,041,525              1,636,652    16,516
#>        PC1 1,379 1,064,000  2,359,511              1,954,638    19,936
```
