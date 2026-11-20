# plancap 0.0.0.9000

## Capacity (stage 4, part 1)

* `estimate_capacity()` turns envelopes into floor area (split between
  residential and business by each zone's use and residential share, by
  storey where it changes) and dwellings, by volumetric, density, hybrid
  and large-site paths; then floor area ratio and maximum site floorspace
  (capping the stack from the ground up), no dwellings without a buildable
  envelope or on land overlays remove, dwellings per site, the access width
  cap, minor dwellings, area totals (including sub-areas sharing a total),
  and entitlements as a floor. Bonuses are reported in `*_with_bonus`
  columns.
* Exclusion overlays: `removes: all` takes land off the buildable ground;
  `removes: residential` keeps floor area over it out of dwellings.

## The envelope engine (stage 3)

* `build_envelopes()` builds each site's storey stack: storeys at the zone's
  own storey height, each tested at its ceiling; one setback per boundary per
  storey (the deepest any applicable rule asks); a single clip with reflex
  corners filled; coverage and landscaping as shares of net site area;
  floorplate caps; a stack that never widens and ends below the minimum
  floorplate. Water yards are measured from the water; access legs come off
  the buildable ground.
* Rules are resolved per site: zone, then precincts and sub-areas (which
  replace), then parameter overlays and height overlays. A change replaces
  whole fields such as `height`, and replaces only the setback kinds it
  names.
* Alternative standards are built separately and each site takes the most
  enabling (or the one named by `variant_choice`).
* `keep_setbacks = TRUE` returns, for every boundary at every storey, the
  setback applied and the rule and citation that set it.
* Incremental runs: given a `baseline`, sites whose inputs are unchanged are
  copied; the result equals a full run.
* Reproduces capacityengine's hand-worked envelope figures through the
  converted Auckland rulebook.

## Scenarios and site preparation (stage 2)

* `scenario()` bundles a rulebook with its parcels, roads, zoning and other
  layers; `scenario_change()` describes a plan change as what differs from a
  base scenario.
* `prepare_sites()` turns a scenario into sites in two cached steps: parcel
  geometry (depends only on parcels, roads, water, centrelines and ground)
  and plan geometry (zoning, overlays, areas). A rule-only change reuses
  both; a zoning change reuses the first.
* Morphology helpers, each returning its evidence: `find_road_frontages()`,
  `find_side_rear()`, `find_corner_sites()`, `find_through_sites()`,
  `find_rear_sites()`, `find_access_legs()`, `find_water_boundaries()`,
  `find_road_widths()` and `site_metrics()`. Boundaries have a class (road,
  side, rear) and tags (reserve, riparian, coastal, lakeside, zone boundary).
* Sites crossed by a zone boundary are split (slivers merged, unzoned
  remainders kept); the zone across each boundary is found by probing
  outward, across the carriageway for road frontages.
* `check_morphology()` compares classification shares with usual ranges;
  `plot_morphology()` draws them.

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
