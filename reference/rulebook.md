# Create a rulebook

A rulebook holds every planning rule for one plan (or one scenario of
it), with a citation for every value. Build it with the `add_*()` and
`set_*()` functions, or read it from a file with
[`read_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md).

## Usage

``` r
rulebook(
  name,
  id = NULL,
  jurisdiction = NULL,
  country = NULL,
  effective_date = NULL,
  source = NULL,
  units = c("m", "ft"),
  hemisphere = NULL
)
```

## Arguments

- name:

  Name of the plan.

- id:

  Short identifier, e.g. `"wcc-dp-2024"`.

- jurisdiction:

  Council, city or state.

- country:

  ISO country code.

- effective_date:

  Date the rules are as at (`"YYYY-MM-DD"`).

- source:

  Where the rules were read from.

- units:

  `"m"` (default) or `"ft"`: units of every length and area in the
  rulebook. Results are always computed in metres.

- hemisphere:

  `"south"` or `"north"`, for rules that depend on which way a boundary
  faces. If `NULL` it is inferred from the data at run time.

## Value

A `plancap_rulebook`.

## Examples

``` r
rb <- rulebook("Exampleton District Plan", id = "exampleton-dp",
               jurisdiction = "Exampleton", country = "NZ")
rb <- add_zone(rb, zone("LDR", "Low Density Residential",
  height = height_limit(8, source = "LDR-S1"),
  setbacks = list(yard(3, "road", source = "LDR-S2")),
  coverage = ratio(0.35, source = "LDR-S3")))
rb
#> <plancap rulebook> Exampleton District Plan
#> exampleton-dp | Exampleton | NZ
#> 1 zone, 0 overlays, 0 areas, 0 bonuses, 0 entitlements; 0 unmodelled rules.
#> Units: metres.
#>  zone label                   method     height setbacks coverage codes
#>  LDR  Low Density Residential volumetric 8      1        0.35     LDR  
```
