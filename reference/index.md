# Package index

## Rulebooks

A rulebook holds every planning rule for one plan, with a citation for
every value. Build one in R, or read it from YAML, JSON or a
spreadsheet.

- [`rulebook()`](https://faceteconomics.github.io/plancap/reference/rulebook.md)
  : Create a rulebook
- [`add_zone()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)
  [`add_overlay()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)
  [`add_area()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)
  [`add_bonus()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)
  [`add_entitlement()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)
  [`add_unmodelled()`](https://faceteconomics.github.io/plancap/reference/add_rules.md)
  : Add rules to a rulebook
- [`set_zone_map()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
  [`set_zone_families()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
  [`set_defaults()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
  [`set_morphology()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
  [`set_conversion()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
  [`set_ground()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
  [`set_variant_choice()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
  : Set rulebook-wide settings
- [`read_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md)
  [`write_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md)
  : Read and write rulebooks
- [`rulebook_template()`](https://faceteconomics.github.io/plancap/reference/rulebook_template.md)
  : Rulebooks as spreadsheets
- [`rulebook_example()`](https://faceteconomics.github.io/plancap/reference/rulebook_example.md)
  [`rulebook_examples()`](https://faceteconomics.github.io/plancap/reference/rulebook_example.md)
  [`rulebook_example_path()`](https://faceteconomics.github.io/plancap/reference/rulebook_example.md)
  : Rulebooks shipped with plancap

## Zones

The rules a zone applies to every site in it.

- [`zone()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  [`zone_changes()`](https://faceteconomics.github.io/plancap/reference/zone.md)
  : Define a zone
- [`height_limit()`](https://faceteconomics.github.io/plancap/reference/height_limit.md)
  : Height limit
- [`ratio()`](https://faceteconomics.github.io/plancap/reference/ratio.md)
  : A share of site area
- [`bands()`](https://faceteconomics.github.io/plancap/reference/bands.md)
  [`band_value()`](https://faceteconomics.github.io/plancap/reference/bands.md)
  : Banded values and ratios
- [`building_form()`](https://faceteconomics.github.io/plancap/reference/building_form.md)
  : Building form limits
- [`density()`](https://faceteconomics.github.io/plancap/reference/density.md)
  : Density rules
- [`use_mix()`](https://faceteconomics.github.io/plancap/reference/use_mix.md)
  : Uses a zone enables

## Setbacks

Yards, recession and daylight planes, upper-level and
height-proportional setbacks: every rule that keeps a building back from
a boundary.

- [`yard()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  [`plane()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  [`upper_level_setback()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  [`proportional_setback()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  [`setback_profile()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  : Setback rules: yards, planes and everything that keeps a building
  back
- [`setback_distance()`](https://faceteconomics.github.io/plancap/reference/setback_distance.md)
  : Required setback distance at a height
- [`conditions()`](https://faceteconomics.github.io/plancap/reference/conditions.md)
  : Conditions under which a rule applies
- [`boundary_classes()`](https://faceteconomics.github.io/plancap/reference/boundary_classes.md)
  : Boundary classes

## Overlays, areas, bonuses and entitlements

- [`overlay()`](https://faceteconomics.github.io/plancap/reference/overlay.md)
  : Overlays: spatial layers that change the rules
- [`area()`](https://faceteconomics.github.io/plancap/reference/area.md)
  : Areas: precincts, sub-precincts and site-specific controls
- [`sub_area()`](https://faceteconomics.github.io/plancap/reference/sub_area.md)
  : A sub-area of an area
- [`bonus()`](https://faceteconomics.github.io/plancap/reference/bonus.md)
  [`entitlement()`](https://faceteconomics.github.io/plancap/reference/bonus.md)
  : Bonuses and entitlements
- [`unmodelled_rule()`](https://faceteconomics.github.io/plancap/reference/unmodelled_rule.md)
  : Record a rule that is not modelled

## Checking and changing rulebooks

- [`validate_rulebook()`](https://faceteconomics.github.io/plancap/reference/validate_rulebook.md)
  : Check a rulebook
- [`rule_table()`](https://faceteconomics.github.io/plancap/reference/rule_table.md)
  : Every rule in a rulebook as one table
- [`set_rule()`](https://faceteconomics.github.io/plancap/reference/set_rule.md)
  [`extend_rulebook()`](https://faceteconomics.github.io/plancap/reference/set_rule.md)
  : Change rules for a what-if or a scenario
- [`convert_rulebook_units()`](https://faceteconomics.github.io/plancap/reference/convert_rulebook_units.md)
  : Convert a rulebook between metres and feet
- [`rulebook_schema_path()`](https://faceteconomics.github.io/plancap/reference/rulebook_schema_path.md)
  : Path to the rulebook JSON Schema

## Values, defaults and assumptions

- [`rule_formula_vars()`](https://faceteconomics.github.io/plancap/reference/rule-formulas.md)
  [`eval_rule_value()`](https://faceteconomics.github.io/plancap/reference/rule-formulas.md)
  : Rule values written as formulas
- [`rulebook_defaults()`](https://faceteconomics.github.io/plancap/reference/rulebook_defaults.md)
  : Rulebook defaults
- [`morphology_defaults()`](https://faceteconomics.github.io/plancap/reference/morphology_defaults.md)
  : Morphology defaults
- [`conversion()`](https://faceteconomics.github.io/plancap/reference/conversion.md)
  : Floor area to dwellings conversion

## Example data

Exampleton, a synthetic town built to exercise every rule type.

- [`exampleton()`](https://faceteconomics.github.io/plancap/reference/exampleton.md)
  [`exampleton_layer()`](https://faceteconomics.github.io/plancap/reference/exampleton.md)
  [`exampleton_layers()`](https://faceteconomics.github.io/plancap/reference/exampleton.md)
  : Exampleton: a synthetic town for examples and tests
- [`exampleton_dem()`](https://faceteconomics.github.io/plancap/reference/exampleton_dem.md)
  : Exampleton ground surface
- [`exampleton_path()`](https://faceteconomics.github.io/plancap/reference/exampleton_path.md)
  : Path to an Exampleton file
