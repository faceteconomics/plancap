# Changelog

## plancap 0.0.0.9000

### Rulebooks (stage 1)

- A rulebook holds every planning rule for one plan, with a citation for
  every value:
  [`rulebook()`](https://faceteconomics.github.io/plancap/reference/rulebook.md),
  [`zone()`](https://faceteconomics.github.io/plancap/reference/zone.md),
  [`height_limit()`](https://faceteconomics.github.io/plancap/reference/height_limit.md),
  [`ratio()`](https://faceteconomics.github.io/plancap/reference/ratio.md),
  [`bands()`](https://faceteconomics.github.io/plancap/reference/bands.md),
  [`building_form()`](https://faceteconomics.github.io/plancap/reference/building_form.md),
  [`density()`](https://faceteconomics.github.io/plancap/reference/density.md),
  [`use_mix()`](https://faceteconomics.github.io/plancap/reference/use_mix.md),
  [`overlay()`](https://faceteconomics.github.io/plancap/reference/overlay.md),
  [`area()`](https://faceteconomics.github.io/plancap/reference/area.md),
  [`sub_area()`](https://faceteconomics.github.io/plancap/reference/sub_area.md),
  [`bonus()`](https://faceteconomics.github.io/plancap/reference/bonus.md),
  [`entitlement()`](https://faceteconomics.github.io/plancap/reference/bonus.md),
  [`unmodelled_rule()`](https://faceteconomics.github.io/plancap/reference/unmodelled_rule.md),
  and the `add_*()` and `set_*()` functions.
- Setback rules all reduce to a required distance as a function of
  height:
  [`yard()`](https://faceteconomics.github.io/plancap/reference/yard.md),
  [`plane()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  (including planes graded by orientation, planes that turn vertical,
  and planes measured from the far side of a road),
  [`upper_level_setback()`](https://faceteconomics.github.io/plancap/reference/yard.md),
  [`proportional_setback()`](https://faceteconomics.github.io/plancap/reference/yard.md)
  and
  [`setback_profile()`](https://faceteconomics.github.io/plancap/reference/yard.md),
  evaluated with
  [`setback_distance()`](https://faceteconomics.github.io/plancap/reference/setback_distance.md).
  Rules apply under
  [`conditions()`](https://faceteconomics.github.io/plancap/reference/conditions.md).
- Any value may be a restricted formula such as `"max(3, 0.4 * H)"`
  ([`eval_rule_value()`](https://faceteconomics.github.io/plancap/reference/rule-formulas.md)).
- Rulebooks read and write losslessly as YAML, JSON and Excel
  ([`read_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md),
  [`write_rulebook()`](https://faceteconomics.github.io/plancap/reference/read_rulebook.md),
  [`rulebook_template()`](https://faceteconomics.github.io/plancap/reference/rulebook_template.md)),
  with `extends:` for scenarios and plan changes. A JSON Schema checks
  structure;
  [`validate_rulebook()`](https://faceteconomics.github.io/plancap/reference/validate_rulebook.md)
  also checks references and missing citations.
- [`rule_table()`](https://faceteconomics.github.io/plancap/reference/rule_table.md)
  lists every rule with its source;
  [`set_rule()`](https://faceteconomics.github.io/plancap/reference/set_rule.md)
  and
  [`extend_rulebook()`](https://faceteconomics.github.io/plancap/reference/set_rule.md)
  change rules for what-ifs;
  [`convert_rulebook_units()`](https://faceteconomics.github.io/plancap/reference/convert_rulebook_units.md)
  converts between metres and feet, formulas included.
- Shipped rulebooks: Exampleton, plus Auckland (operative Unitary Plan,
  all 217 precincts), Christchurch and Wellington as dated worked
  examples converted from the capacityengine project
  ([`rulebook_example()`](https://faceteconomics.github.io/plancap/reference/rulebook_example.md)).

### Example data (stage 0)

- Package skeleton, continuous integration and documentation site.
- The Exampleton synthetic town:
  [`exampleton()`](https://faceteconomics.github.io/plancap/reference/exampleton.md),
  [`exampleton_layer()`](https://faceteconomics.github.io/plancap/reference/exampleton.md),
  [`exampleton_layers()`](https://faceteconomics.github.io/plancap/reference/exampleton.md),
  [`exampleton_dem()`](https://faceteconomics.github.io/plancap/reference/exampleton_dem.md)
  and
  [`exampleton_path()`](https://faceteconomics.github.io/plancap/reference/exampleton_path.md).
