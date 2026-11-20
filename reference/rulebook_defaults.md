# Rulebook defaults

Run-wide assumptions a rulebook may override with
[`set_defaults()`](https://faceteconomics.github.io/plancap/reference/set_rules.md).

## Usage

``` r
rulebook_defaults()
```

## Value

A named list:

- `storey_height`:

  Storey height (m) where the zone and height rule do not imply one. 3.

- `min_floorplate`:

  Smallest storey worth building (m2); smaller storeys end the stack.
  30.

- `level_reference`:

  Where each storey is tested against height and planes: `"ceiling"`
  (the default; a storey must fit entirely) or `"floor"`.

- `terrain`:

  How buildings meet sloping ground, where ground levels are supplied:
  `"stepped"` (the default; each site's ground is a plane fitted to its
  boundaries' ground, and a recession plane is measured from the ground
  at its own boundary) or `"flat"` (one floor at the site's mean
  ground).

- `max_ground_slope`:

  Steepest fitted ground slope (rise over run) accepted; steeper fits
  are scaled back. 0.5.

- `no_limit_height`:

  Stand-in height (m) for zones with no height limit; `NULL` means such
  zones are flagged and given no stand-in.

- `large_site`:

  Large-site treatment: `threshold` (m2, 10,000), `deduction` (share of
  land for roads and reserves, 0.25) and `method` (`"divisor"`:
  dwellings = net land / area per dwelling; or `"envelope"`).

## Examples

``` r
rulebook_defaults()
#> $storey_height
#> [1] 3
#> 
#> $min_floorplate
#> [1] 30
#> 
#> $level_reference
#> [1] "ceiling"
#> 
#> $terrain
#> [1] "stepped"
#> 
#> $max_ground_slope
#> [1] 0.5
#> 
#> $large_site
#> $large_site$threshold
#> [1] 10000
#> 
#> $large_site$deduction
#> [1] 0.25
#> 
#> $large_site$method
#> [1] "divisor"
#> 
#> 
```
