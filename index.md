# plancap

**plancap** estimates the floorspace and dwellings that planning rules
enable on each land parcel, for any jurisdiction, and summarises,
compares and plots the result.

Planning rules (height limits, setbacks, recession or daylight planes,
site coverage, landscaping, floor area ratios, density controls,
overlays and precincts) are entered as a **rulebook**: a validated set
of rules with a citation for every value, written in R, as a YAML file,
or in an Excel template. Capacity is built site by site as a stack of
storey footprints clipped by every rule that applies, then summarised by
zone, height, location or the rule that binds. Plan changes are compared
as scenarios, with the change split into what drove it.

## From parcels to results

``` r

library(plancap)
town <- exampleton()

sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
cap <- estimate_capacity(sc)

summary(cap)                          # headline, by zone, what limits dwellings
check_capacity(cap)                   # reconciliation: parcels, land, storeys
summarise_capacity(cap, by = c("zone", "height_band"))
plot_capacity(cap)                    # floor area by zone
plot_constraints(cap)                 # from the theoretical maximum to enabled
explain_site(cap, "P00001")           # every setback at every storey, with citations
```

A plan change is a scenario that states only what differs:

``` r

pc1 <- exampleton_pc1()
change <- scenario_change(sc, "PC1", rulebook = pc1$rulebook, zoning = pc1$zoning)
cmp <- compare_scenarios(run_scenarios(scenario_set(sc, change)))
plot_attribution(cmp)                 # rules, zoning, overlays, parcels
```

## What it covers

- **Rules**: yards, recession and daylight planes (graded by
  orientation, turning vertical, measured from the far side of a road),
  upper-level and height-proportional setbacks, any setback profile,
  alternative standards, coverage, landscaping, impervious area, floor
  area ratio, floorplate and tower limits, building length and
  separation, the site shape factor, density, access width, height
  overlays and surfaces, exclusions, precincts with dwelling totals,
  bonuses and entitlements; any value may be a formula.
- **Sites**: road, side and rear boundaries, corner, through and rear
  sites, access legs and rights of way, the zone across each boundary,
  water boundaries, sloping ground; every assumption adjustable.
- **Summaries and plots**: one
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md)
  for every breakdown, a constraint waterfall, sensitivity sweeps, maps,
  a 3D view, and comparison plots, in one quiet, colour-blind-safe
  theme.
- **Verified**: it reproduces the capacityengine model exactly on an
  Auckland tile, including the effect of Plan Change 120.

## Rulebooks that ship

``` r

rulebook_examples()
#> "auckland" "christchurch" "exampleton" "exampleton_pc1" "hamilton" "wellington"
```

Exampleton and its plan change are fictional. Auckland, Christchurch,
Wellington and Hamilton are dated worked examples: check the plan before
relying on any value. The vignette *Adding a new jurisdiction: Hamilton*
enters a real plan through the Excel template, from the plan text to
results.

## Scope

plancap estimates **plan-enabled, gross, blank-slate** capacity: what
the rules would allow on each site if no buildings existed. It does not
estimate feasible, infrastructure-ready or likely development. See
*Method and assumptions*.

## Installation

``` r

# install.packages("pak")
pak::pak("faceteconomics/plancap")
```

## Licence

MIT © James Stewart. Exampleton is synthetic. Rulebooks transcribe
public district plans and cite each rule.
