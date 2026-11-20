# Define a zone

A zone holds every rule that applies to sites in it. `zone()` defines a
full zone for
[`add_zone()`](https://faceteconomics.github.io/plancap/reference/add_rules.md);
`zone_changes()` takes the same arguments, all optional, and describes
only what a precinct, overlay or scenario changes.

## Usage

``` r
zone(
  key,
  label = NULL,
  method = c("volumetric", "density", "hybrid", "none"),
  height = NULL,
  setbacks = list(),
  coverage = NULL,
  landscaping = NULL,
  impervious = NULL,
  paved = NULL,
  far = NULL,
  deep_soil = NULL,
  form = NULL,
  density = NULL,
  use = NULL,
  storey_height = NULL,
  ground_floor_height = NULL,
  variants = NULL,
  source = NULL,
  notes = NULL
)

zone_changes(...)
```

## Arguments

- key:

  Short identifier, used everywhere else in the rulebook.

- label:

  Human-readable name.

- method:

  How capacity is estimated: `"volumetric"` (build the storey envelope),
  `"density"` (read dwellings straight off a density rule), `"hybrid"`
  (both; the lesser wins) or `"none"` (the zone carries no capacity but
  is kept so rules that depend on neighbouring zones can see it, e.g.
  open space).

- height:

  A
  [`height_limit()`](https://faceteconomics.github.io/plancap/reference/height_limit.md).

- setbacks:

  A list of setbacks from
  [`yard()`](https://faceteconomics.github.io/plancap/reference/yard.md),
  [`plane()`](https://faceteconomics.github.io/plancap/reference/yard.md),
  [`upper_level_setback()`](https://faceteconomics.github.io/plancap/reference/yard.md),
  [`proportional_setback()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  or
  [`setback_profile()`](https://faceteconomics.github.io/plancap/reference/yard.md).

- coverage, landscaping, impervious, paved, far, deep_soil:

  Site ratio rules: maximum building coverage, minimum landscaped area,
  maximum impervious area, maximum paved area, maximum floor area ratio,
  minimum deep soil. Each a number, a formula string or a
  [`ratio()`](https://faceteconomics.github.io/plancap/reference/ratio.md).

- form:

  Building form limits, from
  [`building_form()`](https://faceteconomics.github.io/plancap/reference/building_form.md).

- density:

  Density rules, from
  [`density()`](https://faceteconomics.github.io/plancap/reference/density.md).

- use:

  Uses enabled and the residential share, from
  [`use_mix()`](https://faceteconomics.github.io/plancap/reference/use_mix.md).

- storey_height, ground_floor_height:

  Storey heights (m). Default from the rulebook defaults.

- variants:

  Named list describing alternative standards; each element a list with
  `label` and `source`. Rules are tied to a variant with their own
  `variant` argument.

- source:

  Citation for the zone.

- notes:

  Free text.

- ...:

  For `zone_changes()`: any arguments of `zone()` except `key`, plus
  `replaces_setbacks`: the setback kinds (`"yard"`, `"plane"`,
  `"upper_level"`, `"proportional"`, `"profile"`) whose rules the
  change's `setbacks` replace. The zone's setbacks of other kinds are
  kept. Defaults to the kinds that appear in the change's `setbacks`;
  give it with an empty `setbacks` list to remove every rule of a kind
  (e.g. a precinct with no recession plane).

## Value

A list with class `plancap_zone`.

## Details

Lengths are in the rulebook's units (metres unless the rulebook says
feet).

## See also

[`add_zone()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)

## Examples

``` r
zone("MRZ", "Medium Density Residential",
  height = height_limit(11, roof_allowance = 1, storeys = 3, source = "MRZ-S1"),
  setbacks = list(
    yard(1.5, "road", source = "MRZ-S4"),
    yard(1, c("side", "rear"), source = "MRZ-S4"),
    plane(60, start_height = 4, boundaries = c("side", "rear"), source = "MRZ-S3")
  ),
  coverage = ratio(0.5, source = "MRZ-S5"),
  landscaping = ratio(0.2, source = "MRZ-S6"))
#> $label
#> [1] "Medium Density Residential"
#> 
#> $method
#> [1] "volumetric"
#> 
#> $height
#> $height$value
#> [1] 11
#> 
#> $height$occupiable
#> [1] 10
#> 
#> $height$roof_allowance
#> [1] 1
#> 
#> $height$storeys
#> [1] 3
#> 
#> $height$source
#> [1] "MRZ-S1"
#> 
#> 
#> $setbacks
#> $setbacks[[1]]
#> $setbacks[[1]]$kind
#> [1] "yard"
#> 
#> $setbacks[[1]]$distance
#> [1] 1.5
#> 
#> $setbacks[[1]]$boundaries
#> [1] "road"
#> 
#> $setbacks[[1]]$source
#> [1] "MRZ-S4"
#> 
#> 
#> $setbacks[[2]]
#> $setbacks[[2]]$kind
#> [1] "yard"
#> 
#> $setbacks[[2]]$distance
#> [1] 1
#> 
#> $setbacks[[2]]$boundaries
#> [1] "side" "rear"
#> 
#> $setbacks[[2]]$source
#> [1] "MRZ-S4"
#> 
#> 
#> $setbacks[[3]]
#> $setbacks[[3]]$kind
#> [1] "plane"
#> 
#> $setbacks[[3]]$angle_deg
#> [1] 60
#> 
#> $setbacks[[3]]$start_height
#> [1] 4
#> 
#> $setbacks[[3]]$boundaries
#> [1] "side" "rear"
#> 
#> $setbacks[[3]]$source
#> [1] "MRZ-S3"
#> 
#> 
#> 
#> $ratios
#> $ratios$coverage_max
#> $ratios$coverage_max$value
#> [1] 0.5
#> 
#> $ratios$coverage_max$source
#> [1] "MRZ-S5"
#> 
#> 
#> $ratios$landscaping_min
#> $ratios$landscaping_min$value
#> [1] 0.2
#> 
#> $ratios$landscaping_min$source
#> [1] "MRZ-S6"
#> 
#> 
#> 
#> attr(,"key")
#> [1] "MRZ"
#> attr(,"class")
#> [1] "plancap_zone"
```
