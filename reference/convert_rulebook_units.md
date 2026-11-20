# Convert a rulebook between metres and feet

Every length and area in a rulebook is in the units its `plan$units`
declares. This converts all of them, including inside formulas and
bands, so a rulebook written in feet can be checked in metres or written
back out in feet. The engine always works in metres.

## Usage

``` r
convert_rulebook_units(rb, to = c("m", "ft"))
```

## Arguments

- rb:

  A `plancap_rulebook`.

- to:

  `"m"` or `"ft"`.

## Value

The converted rulebook.

## Details

Ratios, angles, storey counts and dwellings per hectare are unit-free
and left alone.

## Examples

``` r
rb <- rulebook("Example Code", units = "ft") |>
  add_zone(zone("R1", height = height_limit(35),
                setbacks = list(yard(20, "road"))))
m <- convert_rulebook_units(rb, "m")
m$zones$R1$height$value
#> [1] 10.668
```
