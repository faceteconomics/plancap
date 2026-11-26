# Compare scenarios: what changed, where, and why

Compares each scenario in a set with the baseline (or the `pairs` given)
and returns every view of the change:

## Usage

``` r
compare_scenarios(
  x,
  pairs = NULL,
  areas = NULL,
  area_id = NULL,
  grid = NULL,
  attribution = c("sequential", "shapley", "none"),
  order = c("rules", "zoning", "layers", "parcels"),
  by_rule = TRUE,
  ...
)

# S3 method for class 'plancap_comparison'
summary(object, ...)
```

## Arguments

- x:

  Results from
  [`run_scenarios()`](https://faceteconomics.github.io/plancap/reference/scenario_set.md),
  or a scenario set (run first).

- pairs:

  Optional list of pairs of scenario names to compare; default each
  scenario against the first.

- areas, area_id, grid:

  A common geography, as for
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md).

- attribution:

  `"sequential"`, `"shapley"` or `"none"`.

- order:

  Order of the drivers for sequential attribution.

- by_rule:

  Whether to split the rules driver by rule.

- ...:

  Passed to
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md)
  for the attribution runs.

- object:

  A comparison.

## Value

A `plancap_comparison`: a list with one comparison per pair (`pairs`),
and `totals` for every scenario.
[`check_comparison()`](https://faceteconomics.github.io/plancap/reference/check_comparison.md)
reconciles it.

## Details

- **totals** for each scenario, with the change;

- **sites**: the change on every baseline site. Sites whose parcel is
  the same in both scenarios are compared directly, with a reason code
  (`rezoned`, `rule_changed`, `overlay_added`, `overlay_removed`,
  `area_changed`, `neighbour_effect`, `unchanged`); where parcels
  changed, the scenario's capacity is apportioned to the baseline
  parcels by area (`parcel_changed`). Sites in only one scenario are
  listed, never dropped;

- **transitions**: land and capacity from each baseline zone to each
  scenario zone, the natural way to read a rezoning;

- **by zone**, **by height band**, and **by area** or grid cell when
  `areas` or `grid` are given (a common geography always reconciles);

- **land**: land in each scenario, and land in only one;

- **attribution**: the change split into its drivers (rules, zoning,
  overlay and area layers, parcels), by running intermediate scenarios
  that switch one driver at a time: `"sequential"` (in `order`) or
  `"shapley"` (averaged over every order). With `by_rule = TRUE` the
  rules driver is split further, by each zone, overlay or area whose
  rules changed. The drivers always sum to the total change;

- **inputs**: what changed in the inputs
  ([`diff_inputs()`](https://faceteconomics.github.io/plancap/reference/diff_inputs.md)).

## Examples

``` r
# \donttest{
town <- exampleton()
pc1 <- exampleton_pc1()
base <- scenario("Operative", rulebook_example("exampleton"),
                 parcels = town$parcels[town$parcels$parcel_type == "land", ],
                 roads = town$parcels[town$parcels$parcel_type == "road", ],
                 zoning = town$zoning, layers = town[c("height_areas", "flood_hazard", "transit")])
change <- scenario_change(base, "PC1", rulebook = pc1$rulebook, zoning = pc1$zoning)
cmp <- compare_scenarios(run_scenarios(scenario_set(base, change)))
#> Operative: 4.9 s.
#> PC1: 3.6 s, 575 sites copied from the baseline.
cmp
#> <plancap comparison> baseline "Operative"
#>   scenario sites land_area floor_area residential_floor_area dwellings
#>  Operative 1,379 1,064,000  2,041,525              1,636,652    16,516
#>        PC1 1,379 1,064,000  2,359,511              1,954,638    19,936
#> 
#> ── PC1 against Operative 
#> floor_area: 2,041,525 to 2,359,511 (+317,987, +15.6%)
#> residential_floor_area: 1,636,652 to 1,954,638 (+317,987, +19.4%)
#> dwellings: 16,516 to 19,936 (+3,420, +20.7%)
#> Drivers of the floor area change: rules +206,799, zoning +111,188.
#> Sites: rezoned 337, rule_changed 376, unchanged 664.
# }
```
