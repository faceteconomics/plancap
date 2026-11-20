# Change rules for a what-if or a scenario

`set_rule()` changes one value by its path in the rulebook, for quick
what-if tests. `extend_rulebook()` applies a set of changes at once, the
same way a rulebook file with `extends:` does (see
[`read_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md)).

## Usage

``` r
set_rule(rb, path, value, validate = TRUE)

extend_rulebook(rb, changes, validate = TRUE)
```

## Arguments

- rb:

  A `plancap_rulebook`.

- path:

  Path to the value.

- value:

  New value. `NULL` removes the entry.

- validate:

  If `TRUE`, check the result and stop on errors.

- changes:

  A named list in the rulebook's structure (or a rulebook) whose entries
  override `rb`.

## Value

The changed rulebook.

## Details

Paths are dot-separated names, with `[n]` for the n-th element of a list
(counting from 1), e.g. `"zones.MRZ.height.value"` or
`"zones.MRZ.setbacks[3].start_height"`.

## Examples

``` r
rb <- rulebook("Exampleton") |>
  add_zone(zone("MRZ", height = height_limit(11, source = "MRZ-S1"),
                setbacks = list(yard(1, "side"), plane(60, 4, c("side", "rear")))))
rb2 <- set_rule(rb, "zones.MRZ.height.value", 16)
#> Warning: changed rulebook has 2 warnings; see `validate_rulebook()`.
#> ! /zones/MRZ/setbacks/0: setback has no source
#> ! /zones/MRZ/setbacks/1: setback has no source
rb2 <- set_rule(rb2, "zones.MRZ.setbacks[2].start_height", 6)
#> Warning: changed rulebook has 2 warnings; see `validate_rulebook()`.
#> ! /zones/MRZ/setbacks/0: setback has no source
#> ! /zones/MRZ/setbacks/1: setback has no source
rule_table(rb2)[, c("rule", "value")]
#>            rule           value
#> 1        method      volumetric
#> 2        height              16
#> 3  setback:yard             1 m
#> 4 setback:plane 60 deg from 6 m

rb3 <- extend_rulebook(rb, list(zones = list(MRZ = list(
  ratios = list(coverage_max = list(value = 0.5, source = "PC1"))))))
#> Warning: extended rulebook has 2 warnings; see `validate_rulebook()`.
#> ! /zones/MRZ/setbacks/0: setback has no source
#> ! /zones/MRZ/setbacks/1: setback has no source
rb3$zones$MRZ$ratios
#> $coverage_max
#> $coverage_max$value
#> [1] 0.5
#> 
#> $coverage_max$source
#> [1] "PC1"
#> 
#> 
```
