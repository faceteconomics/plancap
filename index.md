# plancap

**plancap** estimates the floorspace and dwellings that planning rules
enable on each land parcel, for any jurisdiction, and summarises and
plots the result.

Planning rules (height limits, setbacks, recession or daylight planes,
site coverage, landscaping, floor area ratios, density controls,
overlays and precincts) are entered as a **rulebook**: a validated set
of rules with a citation for every value. You can write it as a YAML
file, as a spreadsheet, or in R. Capacity is built site by site as a
stack of storey footprints clipped by every rule that applies. The
results can then be summarised by zone, height, location or the rule
that binds.

> **Status: early development.** The package structure and example data
> are in place; the rulebook, engine, summaries and plots are being
> built in stages. See the [development
> plan](https://faceteconomics.github.io/plancap/PLAN.md).

## Scope

plancap estimates **plan-enabled, gross, blank-slate** capacity: what
the rules would allow on each site if no buildings existed. It does not
estimate feasible, infrastructure-ready or likely development.

## Installation

``` r

# install.packages("pak")
pak::pak("faceteconomics/plancap")
```

## Example data

[`exampleton()`](https://faceteconomics.github.io/plancap/reference/exampleton.md)
loads Exampleton, a synthetic town of about 1,500 parcels built so that
every rule type has something to act on. It has corner, rear and through
lots, a split-zoned block, height areas, a precinct, a river with a
flood plain, protected trees, existing buildings and a ground surface.
It is placed in the open sea so it cannot be mistaken for a real place.

``` r

library(plancap)
town <- exampleton()
names(town)
#>  [1] "parcels"          "road_centrelines" "zoning"           "height_areas"
#>  [5] "flood_hazard"     "heritage"         "precincts"        "water"
#>  [9] "transit"          "trees"            "buildings"
```

## Licence

MIT © James Stewart.
