# Add rules to a rulebook

Pipe-friendly functions that add zones, overlays, areas, bonuses,
entitlements and unmodelled-rule records to a rulebook.

## Usage

``` r
add_zone(rb, ..., codes = NULL)

add_overlay(rb, ...)

add_area(rb, ...)

add_bonus(rb, ...)

add_entitlement(rb, ...)

add_unmodelled(rb, ...)
```

## Arguments

- rb:

  A `plancap_rulebook`.

- ...:

  Objects from
  [`zone()`](https://faceteconomics.github.io/plancap/reference/zone.md),
  [`overlay()`](https://faceteconomics.github.io/plancap/reference/overlay.md),
  [`area()`](https://faceteconomics.github.io/plancap/reference/area.md),
  [`bonus()`](https://faceteconomics.github.io/plancap/reference/bonus.md),
  [`entitlement()`](https://faceteconomics.github.io/plancap/reference/bonus.md)
  or
  [`unmodelled_rule()`](https://faceteconomics.github.io/plancap/reference/unmodelled_rule.md)
  respectively.

- codes:

  For `add_zone()`: the zone codes in the zoning layer that map to this
  zone. Defaults to the zone key. Only valid with one zone.

## Value

The updated rulebook.

## Examples

``` r
rb <- rulebook("Exampleton District Plan")
rb <- rb |>
  add_zone(zone("OS", "Open Space", method = "none")) |>
  add_overlay(overlay("flood", "exclusion", layer = "flood_hazard")) |>
  add_unmodelled(unmodelled_rule("Outlook space", "Placement of windows",
                                 likely_effect = "overstates"))
names(rb$zones)
#> [1] "OS"
```
