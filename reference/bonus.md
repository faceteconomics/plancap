# Bonuses and entitlements

A **bonus** adds to or multiplies a limit when a condition is met (a
floor area bonus for affordable housing, a density bonus). Bonuses are
reported in separate `*_with_bonus` results and never folded into the
base plan-enabled figure.

## Usage

``` r
bonus(
  id,
  quantity = c("far", "height", "dwellings", "floor_area"),
  value,
  combine = c("add", "multiply"),
  applies_to_zones = NULL,
  cap = NULL,
  condition = NULL,
  layer = NULL,
  when = NULL,
  label = NULL,
  source = NULL
)

entitlement(
  id,
  quantity = c("dwellings", "height", "floor_area"),
  value,
  applies_to_zones = NULL,
  layer = NULL,
  when = NULL,
  label = NULL,
  source = NULL
)
```

## Arguments

- id:

  Identifier.

- quantity:

  What is changed: `"far"`, `"height"`, `"dwellings"` or `"floor_area"`.

- value:

  Amount added, multiplier, or guaranteed minimum.

- combine:

  For bonuses: `"add"` or `"multiply"`.

- applies_to_zones:

  Zone keys; `NULL` for all.

- cap:

  Upper limit on the bonus-inclusive value.

- condition:

  Text describing what must be provided to earn the bonus.

- layer:

  Optional layer limiting where it applies.

- when:

  Optional
  [`conditions()`](https://faceteconomics.github.io/plancap/reference/conditions.md).

- label, source:

  Description and citation.

## Value

A list with class `plancap_bonus` or `plancap_entitlement`.

## Details

An **entitlement** is a minimum a plan or a higher law guarantees
whatever the local rules say (three dwellings per site as of right; two
units on a lot). It combines as a floor: the most permissive of it and
the local rules wins.

## Examples

``` r
bonus("affordable", "far", 0.5, combine = "add", applies_to_zones = "TC",
      condition = "10% of dwellings affordable", source = "Rule 12.4")
#> $quantity
#> [1] "far"
#> 
#> $value
#> [1] 0.5
#> 
#> $combine
#> [1] "add"
#> 
#> $applies_to_zones
#> [1] "TC"
#> 
#> $condition
#> [1] "10% of dwellings affordable"
#> 
#> $source
#> [1] "Rule 12.4"
#> 
#> attr(,"id")
#> [1] "affordable"
#> attr(,"class")
#> [1] "plancap_bonus"
entitlement("mdrs", "dwellings", 3, applies_to_zones = c("MDR", "HDR"),
            source = "RMA Schedule 3A, clause 10")
#> $quantity
#> [1] "dwellings"
#> 
#> $value
#> [1] 3
#> 
#> $combine
#> [1] "floor"
#> 
#> $applies_to_zones
#> [1] "MDR" "HDR"
#> 
#> $source
#> [1] "RMA Schedule 3A, clause 10"
#> 
#> attr(,"id")
#> [1] "mdrs"
#> attr(,"class")
#> [1] "plancap_entitlement"
```
