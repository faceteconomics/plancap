# Record a rule that is not modelled

Every rulebook keeps a register of the rules it leaves out, so the
omission is visible to anyone reading the results.

## Usage

``` r
unmodelled_rule(
  rule,
  reason,
  zones = NULL,
  likely_effect = c("overstates", "understates", "either", "unknown"),
  size = NULL,
  source = NULL
)
```

## Arguments

- rule:

  The rule, in words.

- reason:

  Why it is not modelled.

- zones:

  Zone keys it affects; `NULL` for all or unknown.

- likely_effect:

  What leaving it out does to capacity: `"overstates"` (modelling it
  would lower capacity), `"understates"`, `"either"` or `"unknown"`.

- size:

  Estimated size of the effect, where known (free text).

- source:

  Citation.

## Value

A list with class `plancap_unmodelled`.

## Examples

``` r
unmodelled_rule("Rail corridor setback of 1.5 m",
                reason = "No rail boundary class in the cadastre",
                likely_effect = "overstates")
#> $rule
#> [1] "Rail corridor setback of 1.5 m"
#> 
#> $reason
#> [1] "No rail boundary class in the cadastre"
#> 
#> $likely_effect
#> [1] "overstates"
#> 
#> attr(,"class")
#> [1] "plancap_unmodelled"
```
