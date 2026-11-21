# The register of rules not modelled

Every rulebook lists the rules it does not model, with the reason and
the likely direction of the effect on capacity. This returns that
register as a table, for a report's assumptions section.

## Usage

``` r
unmodelled_report(x)
```

## Arguments

- x:

  A rulebook, or a capacity result (its rulebook).

## Value

A data frame: `rule`, `reason`, `zones`, `likely_effect`, `size` and
`source`.

## Examples

``` r
unmodelled_report(rulebook_example("exampleton"))
#>                                        rule
#> 1 Outlook space from principal living rooms
#> 2               Sunlight to the town square
#> 3         Outdoor living space per dwelling
#>                                                                             reason
#> 1 Depends on where windows are placed, which a blank-slate envelope does not know.
#> 2         A shadow-hours test; the sunlight module is planned for a later version.
#> 3 Counted only in the ground budget's full mode, which this rulebook does not use.
#>      zones likely_effect size source
#> 1 MDR, HDR    overstates <NA>   <NA>
#> 2       TC    overstates <NA>   <NA>
#> 3 MDR, HDR    overstates <NA>   <NA>
```
