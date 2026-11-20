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

> **Status: early development.** The rulebook (rules, validation, YAML /
> JSON / Excel input) and example data are in place; site preparation,
> the engine, summaries and plots are being built in stages. See the
> [development plan](https://faceteconomics.github.io/plancap/PLAN.md).

## A rulebook

``` r

library(plancap)

rb <- rulebook("Exampleton District Plan") |>
  add_zone(zone("MDR", "Medium Density Residential",
    height = height_limit(12, roof_allowance = 1, storeys = 3, source = "MDR-S1"),
    setbacks = list(
      yard(2.5, "road", source = "MDR-S3"),
      yard(1, c("side", "rear"), source = "MDR-S3"),
      plane(60, start_height = 4, boundaries = c("side", "rear"), source = "MDR-S2")
    ),
    coverage = ratio(0.5, source = "MDR-S4"),
    landscaping = ratio(0.2, source = "MDR-S5")))

validate_rulebook(rb)
rule_table(rb)
write_rulebook(rb, "exampleton.yaml")   # or .json, or .xlsx for a spreadsheet
```

Rulebooks for Exampleton and, as worked examples, Auckland, Christchurch
and Wellington ship with the package: `rulebook_example("wellington")`.

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
