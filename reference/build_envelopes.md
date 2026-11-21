# Build the storey-by-storey building envelope of every site

The core of the engine: a stack of storey footprints per site, each the
site's buildable ground clipped back from every boundary by every rule
that applies at that storey's height, then capped by coverage,
landscaping and floorplate limits.

## Usage

``` r
build_envelopes(
  x,
  rulebook = NULL,
  variant_choice = NULL,
  include_density = FALSE,
  keep_geometry = FALSE,
  keep_setbacks = FALSE,
  baseline = NULL,
  max_storeys = 60,
  height_add = NULL,
  .only = NULL
)
```

## Arguments

- x:

  A
  [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md),
  or sites from
  [`prepare_sites()`](https://faceteconomics.github.io/plancap/reference/prepare_sites.md)
  (then give `rulebook`).

- rulebook:

  The rulebook, when `x` is prepared sites.

- variant_choice:

  Overrides the rulebook's `variant_choice`.

- include_density:

  Also build envelopes for density-method zones.

- keep_geometry:

  Keep each storey's footprint polygon.

- keep_setbacks:

  Keep, for every boundary at every storey, the setback applied and the
  rule (and citation) that set it. One row per boundary per storey, so
  meant for a few sites, not a region.

- baseline:

  An earlier `plancap_envelope` to copy unchanged sites from.

- max_storeys:

  Guard against a runaway height (not a plan rule).

- height_add:

  Optional named numeric vector, by site id: metres of extra height (as
  a height bonus gives), added to total and occupiable height.

- .only:

  Internal: site ids to build (others are left out), as
  [`explain_site()`](https://faceteconomics.github.io/plancap/reference/explain_site.md)
  uses to rebuild one site.

## Value

A `plancap_envelope`: a list with `stack` (one row per site and storey
of the chosen variant), `sites` (one row per site: variant, storeys,
height reached, footprint, floor area, the constraint that bound most),
`variants` (every variant's total, per site), optional `geometry` and
`setbacks`, a `report` and the per-site `signatures`.

## Method

Carried over from capacityengine, where each choice was tested:

- **Loop over storeys, vectorise over sites.** At each storey every live
  site is handled in one set of GEOS calls.

- **One setback per boundary per storey.** Yards, recession planes,
  upper-level and proportional setbacks all say "at this height, stand
  this far back from this boundary", so the binding distance on a
  boundary is the largest any applicable rule asks, and the clip is a
  single buffer at that distance.

- **A storey is tested at its ceiling** (`level_reference = "ceiling"`):
  the whole storey must fit under a plane.

- **A zone's storey height is its own** (stated height over stated
  storeys), and does not change when an overlay changes the site's
  height.

- **Coverage and landscaping are shares of net site area**, not of the
  clipped envelope, and the most restrictive applies (PLAN 3.5).

- **The stack never widens going up**, and a storey smaller than the
  minimum floorplate ends it.

- **Reflex corners are filled** with wedges, so a bend in a boundary
  away from the site leaves no hairline teeth; parts smaller than a
  floorplate are dropped.

- **Alternative standards are evaluated separately** and each site takes
  the most enabling (`variant_choice = "max"`), or as the rulebook says.

A rule whose condition cannot be evaluated is not guessed at: a positive
trigger (`adjacent_zones`, `facing`, a road width) is not applied, which
overstates; an exemption (`not_adjacent_zones`) is not applied, so the
rule bites, which understates. Both are counted in the run report.

Water yards (setbacks naming `riparian`, `coastal` or `lakeside`) are
measured from the water features themselves, and the land within reach
is taken off the buildable ground.

## Incremental runs

Each site's result carries a signature of everything that determines it:
its geometry and boundaries, its effective rules and the run settings.
Given a `baseline` envelope, sites whose signature is unchanged are
copied from it rather than recomputed, so a plan change that touches a
tenth of the sites costs about a tenth of a run. The result is identical
to a full run.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
  parcels = town$parcels[town$parcels$parcel_type == "land", ][1:60, ],
  roads = town$parcels[town$parcels$parcel_type == "road", ],
  zoning = town$zoning, layers = town["height_areas"])
env <- build_envelopes(sc)
env
#> <plancap envelope> Operative: 60 of 60 sites build; 81,120 m2 of floor area.
#> Plan-enabled, gross, blank-slate building envelope (before yield and use
#> split).
#> Binding constraint by storey: coverage 73%, geometry 27%.
head(env$sites)
#>   site_id zone_key                         param_id         variant storeys
#> 1  P00001      MDR 44c5d8349d2124b4f418d91bfffa29a1 front_exemption       3
#> 2  P00002      MDR 44c5d8349d2124b4f418d91bfffa29a1        standard       3
#> 3  P00003      MDR 44c5d8349d2124b4f418d91bfffa29a1 front_exemption       3
#> 4  P00004      MDR 44c5d8349d2124b4f418d91bfffa29a1 front_exemption       3
#> 5  P00005      MDR 44c5d8349d2124b4f418d91bfffa29a1        standard       3
#> 6  P00006      MDR 44c5d8349d2124b4f418d91bfffa29a1        standard       3
#>   height footprint floor_area  binding flag water_yard_share removed_area
#> 1     11  357.1497  1071.4492 coverage   ok                0            0
#> 2     11  513.1069  1539.3206 coverage   ok                0            0
#> 3     11  389.1607  1167.4821 coverage   ok                0            0
#> 4     11  184.5345   553.6034 coverage   ok                0            0
#> 5     11  290.8621   834.5310 coverage   ok                0            0
#> 6     11  480.3579  1441.0736 coverage   ok                0            0
#>   storeys_allowed
#> 1               3
#> 2               3
#> 3               3
#> 4               3
#> 5               3
#> 6               3
```
