# Read and write rulebooks

Rulebooks are stored as YAML (`.yaml`, `.yml`), JSON (`.json`) or a
spreadsheet (`.xlsx`, see
[`rulebook_template()`](https://faceteconomics.github.io/plancap/reference/rulebook_template.md)).
All three hold the same structure, described by the JSON Schema returned
by
[`rulebook_schema_path()`](https://faceteconomics.github.io/plancap/reference/rulebook_schema_path.md).

## Usage

``` r
read_rulebook(path, validate = TRUE)

write_rulebook(rb, path, units = NULL)
```

## Arguments

- path:

  File path.

- validate:

  If `TRUE` (default), check the rulebook with
  [`validate_rulebook()`](https://faceteconomics.github.io/plancap/reference/validate_rulebook.md).
  Errors stop reading; warnings are reported.

- rb:

  A `plancap_rulebook`.

- units:

  Optionally convert to `"m"` or `"ft"` before writing.

## Value

`read_rulebook()` returns a `plancap_rulebook`. `write_rulebook()`
returns `path`, invisibly.

## Details

A YAML or JSON rulebook may start with `extends: other.yaml` (a path
relative to the file). It is then read as a set of changes to that
rulebook: named entries replace or merge into the base, lists (such as a
zone's setbacks) replace the base's list whole, and an entry set to
`null` (`~` in YAML) is removed. This is how scenarios and plan changes
are written.

## Examples

``` r
rb <- rulebook("Exampleton District Plan") |>
  add_zone(zone("LDR", height = height_limit(8, source = "LDR-S1")))
f <- tempfile(fileext = ".yaml")
write_rulebook(rb, f)
identical(read_rulebook(f)$zones, rb$zones)
#> [1] TRUE
```
