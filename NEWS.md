# plancap 0.0.0.9000

## Rulebooks (stage 1)

* A rulebook holds every planning rule for one plan, with a citation for
  every value: `rulebook()`, `zone()`, `height_limit()`, `ratio()`, `bands()`,
  `building_form()`, `density()`, `use_mix()`, `overlay()`, `area()`,
  `sub_area()`, `bonus()`, `entitlement()`, `unmodelled_rule()`, and the
  `add_*()` and `set_*()` functions.
* Setback rules all reduce to a required distance as a function of height:
  `yard()`, `plane()` (including planes graded by orientation, planes that turn
  vertical, and planes measured from the far side of a road),
  `upper_level_setback()`, `proportional_setback()` and `setback_profile()`,
  evaluated with `setback_distance()`. Rules apply under `conditions()`.
* Any value may be a restricted formula such as `"max(3, 0.4 * H)"`
  (`eval_rule_value()`).
* Rulebooks read and write losslessly as YAML, JSON and Excel
  (`read_rulebook()`, `write_rulebook()`, `rulebook_template()`), with
  `extends:` for scenarios and plan changes. A JSON Schema checks structure;
  `validate_rulebook()` also checks references and missing citations.
* `rule_table()` lists every rule with its source; `set_rule()` and
  `extend_rulebook()` change rules for what-ifs; `convert_rulebook_units()`
  converts between metres and feet, formulas included.
* Shipped rulebooks: Exampleton, plus Auckland (operative Unitary Plan, all
  217 precincts), Christchurch and Wellington as dated worked examples
  converted from the capacityengine project (`rulebook_example()`).

## Example data (stage 0)

* Package skeleton, continuous integration and documentation site.
* The Exampleton synthetic town: `exampleton()`, `exampleton_layer()`,
  `exampleton_layers()`, `exampleton_dem()` and `exampleton_path()`.
