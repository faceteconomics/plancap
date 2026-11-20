# Rulebooks as spreadsheets

For people who would rather not write YAML or R, a rulebook can be kept
as an Excel workbook. `rulebook_template()` writes an annotated, empty
workbook (or one filled from an existing rulebook) with drop-down lists
for every choice;
[`read_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md)
reads it back.

## Usage

``` r
rulebook_template(path, rb = NULL)
```

## Arguments

- path:

  Path of the `.xlsx` file to write.

- rb:

  Optional rulebook to fill the template from.

## Value

`path`, invisibly.

## Details

The workbook has one sheet per kind of rule:

|  |  |
|----|----|
| Sheet | One row per |
| `plan` | setting (plan details, defaults, conversion, ground budget, morphology) |
| `zones` | zone: height, site ratios, building form, density, uses |
| `setbacks` | yard, plane or other setback, with its conditions |
| `bands` | band of a value that changes in steps (e.g. coverage by site area) |
| `families` | zone family |
| `overlays` | overlay |
| `areas` | precinct or other area |
| `changes` | set of zone changes made by an overlay, area or sub-area |
| `bonuses`, `entitlements` | bonus or entitlement |
| `unmodelled` | rule not modelled |
| `variants`, `unit_mix`, `access_width` | the rarer tables |
| `fields` | (read-only) what every column means |

In `setbacks`, `bands` and `access_width`, the `target` column names
what the row belongs to: a zone key (`MRZ`), an overlay's changes
(`overlay:character`), an area's changes (`area:quarry`), an area's
changes for one zone (`area:quarry/zone:MRZ`) or a sub-area
(`area:quarry/sub:B`).

Lists inside a cell are comma-separated (`side, rear`). Any number may
be a formula, written as text (`max(3, 0.4 * H)`).

## Examples

``` r
f <- tempfile(fileext = ".xlsx")
rulebook_template(f)
openxlsx2::wb_load(f)$sheet_names
#>  [1] "README"       "plan"         "zones"        "setbacks"     "bands"       
#>  [6] "families"     "overlays"     "areas"        "changes"      "bonuses"     
#> [11] "entitlements" "unmodelled"   "variants"     "unit_mix"     "access_width"
#> [16] "fields"      
```
