# Set rulebook-wide settings

Set rulebook-wide settings

## Usage

``` r
set_zone_map(rb, ...)

set_zone_families(rb, ...)

set_defaults(rb, ...)

set_morphology(rb, ...)

set_conversion(rb, x)

set_ground(
  rb,
  mode = c("most_restrictive", "with_access", "full"),
  overlap = NULL,
  parking_area_per_dwelling = NULL,
  outdoor_area_per_dwelling = NULL
)

set_variant_choice(rb, choice = "max")
```

## Arguments

- rb:

  A `plancap_rulebook`.

- ...:

  Named values. For `set_zone_map()`: zone code = zone key. For
  `set_zone_families()`: family name = character vector of zone keys.
  For `set_defaults()` and `set_morphology()`: names from
  [`rulebook_defaults()`](https://faceteconomics.github.io/plancap/reference/rulebook_defaults.md)
  and
  [`morphology_defaults()`](https://faceteconomics.github.io/plancap/reference/morphology_defaults.md).

- x:

  For `set_conversion()`: a
  [`conversion()`](https://faceteconomics.github.io/plancap/reference/conversion.md).

- mode:

  For `set_ground()`: how the ground budget treats paving.
  `"most_restrictive"` (default; footprint is the least of coverage and
  what landscaping and impervious limits leave, assuming no paving),
  `"with_access"` (also deducts measured access legs and any parking and
  manoeuvring allowance) or `"full"` (also deducts outdoor space
  required per dwelling).

- overlap:

  For `set_ground()`: named logicals saying which ground may count
  twice: `outdoor_living_counts_as_landscaping`,
  `landscaping_on_structure`, `deep_soil_counts_as_landscaping`.

- parking_area_per_dwelling:

  For `set_ground()`: surface parking and manoeuvring area (m2) needed
  per dwelling in `"with_access"` and `"full"` modes.

- outdoor_area_per_dwelling:

  For `set_ground()`: outdoor living space (m2) at ground per dwelling
  in `"full"` mode.

- choice:

  For `set_variant_choice()`: `"max"` (default: each site takes the most
  enabling of its permitted alternative standards), `"min"`, or the name
  of one variant.

## Value

The updated rulebook.

## Examples

``` r
rb <- rulebook("Exampleton District Plan") |>
  set_zone_families(RESIDENTIAL = c("LDR", "MDR", "HDR")) |>
  set_morphology(corner_angle_tolerance = 25) |>
  set_conversion(conversion(dwelling_size = 90))
rb$morphology
#> $corner_angle_tolerance
#> [1] 25
#> 
```
