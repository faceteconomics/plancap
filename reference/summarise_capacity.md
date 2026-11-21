# Summarise capacity by zone, height, size, location or binding constraint

One function for every breakdown of a capacity result. `by` names what
to group by; `measures` names what to report. Every site is counted
once, in one group, so groups always add up to the total.

## Usage

``` r
summarise_capacity(
  cap,
  by = "zone",
  measures = default_measures(),
  areas = NULL,
  area_id = NULL,
  grid = NULL,
  breaks = list(),
  include_zero = TRUE
)

default_measures()
```

## Arguments

- cap:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- by:

  Character vector of groupings (see the section); `NULL` for one total
  row.

- measures:

  Character vector of measures.

- areas:

  Polygons for `by = "area"`.

- area_id:

  Column of `areas` naming each area.

- grid:

  Cell size (m) for `by = "grid"`.

- breaks:

  Named list overriding the band breaks: `height` (m), `site_size` (m2)
  and `far`.

- include_zero:

  Whether sites with no capacity (open space, unzoned) are counted. They
  are by default, so land area reconciles.

## Value

A data frame of class `plancap_summary`, one row per group; an `sf` data
frame of the areas or cells for a spatial grouping.

## Grouping (`by`)

Any column of `cap$sites` (such as `zone_key`, `zone_code`, `method`,
`path`, `variant`, `flag`, `envelope_binding`, `dwelling_binding`), and:

- `"zone"`: the zone key;

- `"storeys"`: the number of storeys the envelope reaches;

- `"height_band"`: the envelope's height, in bands (`breaks$height`);

- `"site_size_band"`: site area, in bands (`breaks$site_size`);

- `"far_band"`: the floor area ratio achieved, in bands (`breaks$far`);

- `"binding"`: the constraint that limits dwellings
  (`dwelling_binding`);

- `"area"`: the polygons given as `areas`, labelled by `area_id`; each
  site is assigned to the area that covers most of it ("(outside)" where
  none does);

- `"grid"`: square cells of `grid` metres, by each site's point on
  surface;

- `"storey"`: floor area **by storey level** (where capacity sits
  vertically), from the storey stack: a site counts in every storey it
  reaches, and only floor area measures apply.

## Measures

`sites`, `land_area`, `footprint`, `floor_area`,
`residential_floor_area`, `business_floor_area`, `dwellings`,
`minor_dwellings`, `floor_area_mean` and `floor_area_median` (per site),
`dwellings_mean`, `far` (floor area over land area), `floor_area_per_ha`
and `dwellings_per_ha` (of land), `floor_area_share` and
`dwellings_share` (of the total), and the `*_with_bonus` columns.
`"gfa"` is accepted for `floor_area`.

## See also

[`capacity_table()`](https://faceteconomics.github.io/plancap/reference/capacity_table.md)
to format it;
[`summary.plancap_capacity()`](https://faceteconomics.github.io/plancap/reference/summary.plancap_capacity.md)

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
cap <- estimate_capacity(sc)
summarise_capacity(cap)
#> <plancap summary> Operative, by zone_key: 6 rows
#>  zone_key sites land_area floor_area dwellings  far floor_area_share
#>       HDR   272   215,500    529,519     5,594 2.46            25.4%
#>       IND    24    48,000    115,200         0 2.40             5.5%
#>       LDR   108    96,000     64,920       103 0.68             3.1%
#>       MDR   714   512,500    737,704     7,644 1.44            35.3%
#>        MU   176   128,000    384,000     2,132 3.00            18.4%
#>        TC    85    64,000    256,000     1,342 4.00            12.3%
summarise_capacity(cap, by = c("zone", "height_band"), measures = c("sites", "floor_area"))
#> <plancap summary> Operative, by zone_key, height_band: 9 rows
#>  zone_key height_band sites floor_area
#>       HDR       0-9 m     2        434
#>       HDR     12-16 m    25     17,944
#>       HDR     16-22 m    96    153,944
#>       HDR     22-30 m   149    357,196
#>       IND     12-16 m    24    115,200
#>       LDR       0-9 m   108     64,920
#>       MDR      9-12 m   714    737,704
#>        MU     12-16 m   176    384,000
#>        TC     22-30 m    85    256,000
summarise_capacity(cap, by = "storey")
#> <plancap summary> Operative, by storey: 6 rows
#>  storey sites floor_area floor_area_share
#>       1 1,379    643,225            30.8%
#>       2 1,378    641,683            30.7%
#>       3 1,269    592,126            28.4%
#>       4   355    149,980             7.2%
#>       5   245     43,497             2.1%
#>       6   149     16,832             0.8%
```
