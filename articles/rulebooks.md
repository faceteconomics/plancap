# Writing a rulebook

A **rulebook** holds every planning rule of one plan that bears on how
much can be built: zones, overlays, precincts and other areas, bonuses
and entitlements, with the assumptions that turn floor area into
dwellings. Every value carries a citation (`source`), so any result can
be traced back to the rule that produced it.

There are three ways to write one, and they hold exactly the same thing:

- **in R**, with constructor functions;
- **as a file**, YAML or JSON, checked against a JSON Schema;
- **in a spreadsheet**, the Excel template, for people who would rather
  not write code.

``` r

library(plancap)
#> 
#> Attaching package: 'plancap'
#> The following object is masked from 'package:stats':
#> 
#>     density
```

## In R

``` r

rb <- rulebook("Riverside District Plan", id = "riverside-dp", jurisdiction = "Riverside",
               country = "NZ", effective_date = "2026-07-01",
               source = "Riverside District Plan (fictional), operative 1 July 2026") |>
  add_zone(
    zone("RES", "Residential", method = "volumetric",
         height = height_limit(11, storeys = 3, source = "RES-S1"),
         setbacks = list(
           yard(3, "road", source = "RES-S3"),
           yard(1, c("side", "rear"), source = "RES-S3"),
           plane(45, start_height = 3, boundaries = c("side", "rear"), source = "RES-S2")),
         coverage = ratio(0.5, source = "RES-S4"),
         landscaping = ratio(0.25, source = "RES-S5"),
         density = density(min_dwelling_size = 35, source = "RES-S8"),
         source = "Chapter RES"),
    zone("OS", "Open space", method = "none", source = "Chapter OS")) |>
  set_conversion(conversion(dwelling_size = 90, efficiency = 0.85,
                            source = "Assumed average dwelling, 85% of floor area in dwellings"))
rb
#> <plancap rulebook> Riverside District Plan
#> riverside-dp | Riverside | NZ | as at 2026-07-01
#> 2 zones, 0 overlays, 0 areas, 0 bonuses, 0 entitlements; 0 unmodelled rules.
#> Units: metres.
#>  zone label       method     height setbacks coverage codes
#>  RES  Residential volumetric 11     3        0.5      RES  
#>  OS   Open space  none              0                 OS
validate_rulebook(rb)
#> ✔ Rulebook is valid (0 warnings, 0 notes).
```

[`rule_table()`](https://faceteconomics.github.io/plancap/reference/rule_table.md)
lists every rule with its citation, the form a report’s appendix needs:

``` r

rule_table(rb)[, c("zone", "rule", "value", "applies_to", "source")]
#>   zone                      rule           value applies_to      source
#> 1  RES                    method      volumetric       <NA> Chapter RES
#> 2  RES                    height   11; 3 storeys       <NA>      RES-S1
#> 3  RES              setback:yard             3 m       road      RES-S3
#> 4  RES              setback:yard             1 m side, rear      RES-S3
#> 5  RES             setback:plane 45 deg from 3 m side, rear      RES-S2
#> 6  RES              coverage_max             0.5       <NA>      RES-S4
#> 7  RES           landscaping_min            0.25       <NA>      RES-S5
#> 8  RES density.min_dwelling_size              35       <NA>      RES-S8
#> 9   OS                    method            none       <NA>  Chapter OS
```

Any value may be a **formula** of the site and the building, written as
text (see `?rule-formulas`):

``` r

yard("max(3, 0.4 * H)", "road", source = "RES-S3A: the greater of 3 m and 0.4 times the height")
#> <setback: yard> on "road"
#>  $ distance:"max(3, 0.4 * H)"
#>  $ source  :"RES-S3A: the greater of 3 m and 0.4 times the height"
```

## As a file

[`write_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md)
and
[`read_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md)
round-trip YAML, JSON and Excel without loss:

``` r

f <- tempfile(fileext = ".yaml")
write_rulebook(rb, f)
cat(readLines(f)[1:30], sep = "\n")
#> # plancap rulebook (schema 0.1)
#> # Riverside District Plan
#> schema_version: '0.1'
#> plan:
#>   name: Riverside District Plan
#>   id: riverside-dp
#>   jurisdiction: Riverside
#>   country: NZ
#>   effective_date: '2026-07-01'
#>   units: m
#>   source: Riverside District Plan (fictional), operative 1 July 2026
#> defaults:
#>   storey_height: 3.0
#>   min_floorplate: 30.0
#>   level_reference: ceiling
#>   terrain: stepped
#>   max_ground_slope: 0.5
#>   site_shape_factor: yes
#>   large_site:
#>     method: divisor
#>     threshold: 10000.0
#>     deduction: 0.25
#> conversion:
#>   dwelling_size: 90.0
#>   efficiency: 0.85
#>   min_one_dwelling: yes
#>   source: Assumed average dwelling, 85% of floor area in dwellings
#> variant_choice: max
#> zone_map:
#>   RES: RES
identical(read_rulebook(f)$zones, rb$zones)
#> [1] FALSE
```

A file may start with `extends: other.yaml` and state only what changes.
That is how a plan change is written (see the PC1 example,
`rulebook_example_path("exampleton_pc1")`).

## In a spreadsheet

[`rulebook_template()`](https://faceteconomics.github.io/plancap/reference/rulebook_template.md)
writes an annotated workbook with one sheet per kind of rule, drop-down
lists for every choice, and a `fields` sheet explaining each column.
Give it a rulebook to start from that one:

``` r

x <- tempfile(fileext = ".xlsx")
rulebook_template(x, rb)
openxlsx2::wb_load(x)$sheet_names
#>  [1] "README"       "plan"         "zones"        "setbacks"     "bands"       
#>  [6] "families"     "overlays"     "areas"        "changes"      "bonuses"     
#> [11] "entitlements" "unmodelled"   "variants"     "unit_mix"     "access_width"
#> [16] "fields"
openxlsx2::read_xlsx(x, sheet = "setbacks")[, c("target", "kind", "boundaries", "distance", "angle_deg",
                                                "start_height", "source")]
#>   target  kind boundaries distance angle_deg start_height source
#> 2    RES  yard       road        3      <NA>         <NA> RES-S3
#> 3    RES  yard side, rear        1      <NA>         <NA> RES-S3
#> 4    RES plane side, rear     <NA>        45            3 RES-S2
identical(read_rulebook(x)$zones$RES$height, rb$zones$RES$height)
#> [1] TRUE
```

The vignette *Adding a new jurisdiction: Hamilton* enters a real plan
this way, from the plan text to results.

## Citations and what is not modelled

[`validate_rulebook()`](https://faceteconomics.github.io/plancap/reference/validate_rulebook.md)
reports values without a `source`. Rules a rulebook does not model
(because they need information a blank-slate envelope does not have, or
a layer that is not held) are listed with
[`unmodelled_rule()`](https://faceteconomics.github.io/plancap/reference/unmodelled_rule.md),
with the direction they would move capacity, and reported by
[`unmodelled_report()`](https://faceteconomics.github.io/plancap/reference/unmodelled_report.md):

``` r

rb2 <- rb
rb2$unmodelled_rules <- list(unmodelled_rule("Outlook space from principal living rooms",
                                             reason = "Depends on window placement.",
                                             zones = "RES", likely_effect = "overstates"))
unmodelled_report(rb2)
#>                                        rule                       reason zones
#> 1 Outlook space from principal living rooms Depends on window placement.   RES
#>   likely_effect size source
#> 1    overstates <NA>   <NA>
```

## Shipped rulebooks

``` r

rulebook_examples()
#> [1] "auckland"       "christchurch"   "exampleton_pc1" "exampleton"    
#> [5] "hamilton"       "wellington"
```

Exampleton and its plan change are fictional. Auckland, Christchurch and
Wellington are converted from the capacityengine project and Hamilton
was entered through the template: they are dated worked examples,
maintained by the package author. Check the plan itself before relying
on any value.
