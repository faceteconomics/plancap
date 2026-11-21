# Floor area lost to each kind of rule

A waterfall from a theoretical maximum (every site built over its whole
area to as many storeys as its height allows) down to the enabled floor
area, in the order the engine applies the rules:

## Usage

``` r
constraint_breakdown(cap, by = NULL)
```

## Arguments

- cap:

  A capacity result from
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md).

- by:

  Optional grouping, as for
  [`summarise_capacity()`](https://faceteconomics.github.io/plancap/reference/summarise_capacity.md)
  (site columns or `"zone"`).

## Value

A data frame of class `plancap_breakdown`: the grouping columns, `step`,
`floor_area` (the loss, or for the first and last steps the amount) and
`remaining` after the step.

## Details

1.  `storeys_not_reached`: storeys the height allows that the stack
    never reaches, because setbacks, planes or caps left too small a
    floor;

2.  `setbacks_and_land`: land each built storey loses to yards, planes,
    access legs, water yards, exclusions, height surfaces and building
    gaps;

3.  one step per cap that bound a storey (`coverage`, `landscaping`,
    `impervious`, `floorplate`, `tower_floorplate`, and
    `stack_monotonic`, a storey kept no larger than the one below);

4.  `far` and `max_site_floorspace`: limits on the site's total.

The steps add up exactly: the theoretical maximum less every loss is the
enabled floor area.

## Examples

``` r
town <- exampleton()
sc <- scenario("Operative", rulebook_example("exampleton"),
               parcels = town$parcels[town$parcels$parcel_type == "land", ],
               roads = town$parcels[town$parcels$parcel_type == "road", ],
               zoning = town$zoning, layers = town[c("height_areas", "transit")])
constraint_breakdown(estimate_capacity(sc))
#> <plancap constraint breakdown> Operative
#>                 step floor_area remaining
#>          theoretical  4,126,500 4,126,500
#>  storeys_not_reached     89,916 4,036,584
#>    setbacks_and_land  1,241,836 2,794,748
#>             coverage    405,693 2,389,055
#>                  far    301,712 2,087,343
#>              enabled  2,087,343 2,087,343
```
