# Prepare sites for a scenario

Turns a scenario's parcels and maps into sites ready for the engine, in
two steps whose results are kept and reused:

## Usage

``` r
prepare_sites(x, cache = TRUE)
```

## Arguments

- x:

  A
  [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md).

- cache:

  Whether to reuse and store prepared steps (in memory, for the
  session).

## Value

A `plancap_sites` object: a list with `sites` (one row per site, `sf`),
`segments` (one row per boundary segment, `sf`), `access_legs`,
`overlays` and `areas` (site membership, with the share of each site
covered), `distances`, a `report` of anything that could not be done,
and the `hashes` of its inputs.

## Details

1.  **Parcel geometry**, which depends only on parcels, roads, water,
    road centrelines and the ground surface: sites, boundary segments
    and their classes, frontages, corner, through and rear sites, access
    legs, road widths (see
    [morphology](https://faceteconomics.github.io/plancap/reference/morphology.md)).

2.  **Plan geometry**, which also depends on the zoning, overlay and
    area layers: sites split where zones cross them (only those sites
    are reclassified), the zone across each boundary, overlay and area
    membership, and distances to features rules refer to.

Each step is stored under a hash of its inputs. A second scenario with
the same parcels reuses step 1; one that changes only rule values reuses
both. Nothing here depends on rule values, so a rule-only change costs
nothing.

## Examples

``` r
town <- exampleton()
base <- scenario("Operative", rulebook_example("exampleton"),
                 parcels = town$parcels[town$parcels$parcel_type == "land", ],
                 roads = town$parcels[town$parcels$parcel_type == "road", ],
                 zoning = town$zoning, layers = town[c("height_areas", "precincts")])
s <- prepare_sites(base)
s
#> <plancap sites> Operative: 1379 sites, 5912 boundary segments.
#> Zones: MDR 714, HDR 272, MU 176, LDR 108, TC 85, IND 24.
#> Corner 295, through 9, rear 144 (142 with access legs); split by zone 2.
#> Reused: parcel_geometry.
#> ! adjacency_unresolved: 173
#> ! overlay_layers_missing: flood_hazard, heritage, trees
#> ! distance_layers_missing: transit
table(s$segments$boundary_class)
#> 
#> rear road side 
#> 1397 1683 2832 
```
