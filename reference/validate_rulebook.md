# Check a rulebook

Checks a rulebook in three passes:

## Usage

``` r
validate_rulebook(rb)
```

## Arguments

- rb:

  A `plancap_rulebook`.

## Value

A `plancap_validation`: a list with `valid` (no errors) and `issues`, a
data frame of `severity`, `path` and `message`.

## Details

1.  **Structure**, against the JSON Schema
    ([`rulebook_schema_path()`](https://faceteconomics.github.io/plancap/reference/rulebook_schema_path.md)):
    every key known, every value the right type. A misspelt key is an
    error, not silently ignored.

2.  **Consistency**: every zone, family, overlay and layer a rule refers
    to exists; bands ascend; formulas use only known variables; each
    zone has what its method needs.

3.  **Lint** (warnings): values without a citation, zones no code maps
    to, rules that nothing will read.

## Examples

``` r
rb <- rulebook("Exampleton") |>
  add_zone(zone("LDR", height = height_limit(8)))
validate_rulebook(rb)
#> ✔ Rulebook is valid (2 warnings, 1 note).
#> ! /zones/LDR: no citation anywhere in this zone
#> ! /zones/LDR/height: height has no source
#> ℹ /conversion: no floor area to dwellings conversion; dwellings need one at run
#>   time
```
