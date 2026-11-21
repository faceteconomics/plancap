# Estimate plan-enabled capacity

Turns each site's building envelope into floor area (residential and
business) and dwellings, by the path its zone's method sets:

## Usage

``` r
estimate_capacity(
  x,
  envelope = NULL,
  baseline = NULL,
  conversion = NULL,
  ...,
  .height_bonus = TRUE
)
```

## Arguments

- x:

  A
  [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md).

- envelope:

  Optional envelope from
  [`build_envelopes()`](https://faceteconomics.github.io/plancap/reference/build_envelopes.md)
  for `x`, to avoid rebuilding it.

- baseline:

  Optional earlier `plancap_capacity`: sites whose inputs are unchanged
  are copied (see
  [`build_envelopes()`](https://faceteconomics.github.io/plancap/reference/build_envelopes.md)).

- conversion:

  Optional
  [`conversion()`](https://faceteconomics.github.io/plancap/reference/conversion.md)
  overriding the rulebook's.

- ...:

  Passed to
  [`build_envelopes()`](https://faceteconomics.github.io/plancap/reference/build_envelopes.md).

- .height_bonus:

  Internal: whether to evaluate height bonuses (the second, bonus run
  sets this to `FALSE`).

## Value

A `plancap_capacity` object: `sites` (`sf`, one row per site, every site
kept, with floor area, dwellings, the path and binding constraints and
flags), `stack` (per storey, with the residential and business split),
the `envelope`, the `rulebook`, the `conversion` used and a `report`.

## Details

- **volumetric**: floor area from the envelope, split between
  residential and business by the zone's `use`, and residential floor
  area converted to dwellings by the rulebook's
  [`conversion()`](https://faceteconomics.github.io/plancap/reference/conversion.md);

- **density**: dwellings straight from the density rule (dwellings per
  hectare, land per dwelling, or the vacant-site minimum), at least one
  on an existing lot;

- **hybrid**: both, the lesser counts;

- **large sites** (at least `defaults$large_site$threshold`): dwellings
  by the land less the infrastructure deduction over a land area per
  dwelling, where the rulebook gives one
  (`large_site$method = "divisor"`, or any density zone); envelope sites
  over the threshold take the deduction on their envelope's dwellings.

Then, in this order: floor area ratio and maximum site floorspace
(capping the stack from the ground up), no dwellings on a site whose
envelope holds no floor (unless a water yard emptied it) or whose land
overlays removed, maximum dwellings per site, the access width cap,
minor dwellings (their own column), area totals (a precinct's dwelling
cap), and entitlements (a minimum guaranteed by law, applied as a
floor). Bonuses are reported apart, in `*_with_bonus` columns.

Results are **plan-enabled, gross, blank-slate**: what the rules allow
if no buildings existed, before feasibility or take-up.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
  parcels = town$parcels[town$parcels$parcel_type == "land", ][1:80, ],
  roads = town$parcels[town$parcels$parcel_type == "road", ],
  zoning = town$zoning, layers = town[c("height_areas", "transit")])
cap <- estimate_capacity(sc)
cap
#> <plancap capacity> Operative: 80 sites, 117,251 m2 floor area (98,051 m2
#> residential), 1,024 dwellings (+0 minor).
#> Plan-enabled, gross, blank-slate capacity; dwellings at 78 m2 and 85%
#> efficiency.
#> Paths: volumetric 80.
#> With bonuses: +1 dwellings.
```
