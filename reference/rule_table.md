# Every rule in a rulebook as one table

Flattens a rulebook into a long table with one row per rule: what it
applies to, what it says, the conditions on it, and its citation. Useful
as an appendix to a report, and for checking a rulebook against the
plan.

## Usage

``` r
rule_table(rb)
```

## Arguments

- rb:

  A `plancap_rulebook`.

## Value

A data frame with columns `scope` (`"zone"`, `"overlay"`, `"area"`,
`"bonus"`, `"entitlement"` or `"unmodelled"`), `id`, `zone`, `rule`,
`value`, `applies_to`, `conditions`, `variant` and `source`.

## Examples

``` r
rb <- rulebook("Exampleton") |>
  add_zone(zone("LDR", height = height_limit(8, source = "LDR-S1"),
                setbacks = list(yard(3, "road", source = "LDR-S2")),
                coverage = ratio(0.35, source = "LDR-S3")))
rule_table(rb)
#>   scope  id zone         rule      value applies_to conditions variant source
#> 1  zone LDR  LDR       method volumetric       <NA>       <NA>    <NA>   <NA>
#> 2  zone LDR  LDR       height          8       <NA>       <NA>    <NA> LDR-S1
#> 3  zone LDR  LDR setback:yard        3 m       road       <NA>    <NA> LDR-S2
#> 4  zone LDR  LDR coverage_max       0.35       <NA>       <NA>    <NA> LDR-S3
```
