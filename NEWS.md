# plancap 0.0.0.9000

## A new jurisdiction, maps in 3D, documentation (stage 8)

* Hamilton, New Zealand, entered through the Excel template from the
  Operative District Plan (revision of 13 November 2026, with Plan Change
  12): General, Medium and High Density Residential, Business 6 and Business
  2, every value cited, with seven rules registered as not modelled
  (`rulebook_example("hamilton")`, `inst/extdata/hamilton_rulebook.xlsx`).
  The vignette "Adding a new jurisdiction: Hamilton" follows it from the plan
  text to results, including a "permitted activities only" scenario.
* `view_capacity_3d()`: an interactive 3D map (mapgl), sites raised to their
  height or each storey's footprint at its level, coloured by capacity per
  hectare.
* `plot_capacity_map()` and `plot_change_map()` take `basemap = TRUE` (Esri's
  World Gray Canvas, or any maptiles provider).
* Fixed: a blank Excel template's `families` sheet had no `family` column.
* Vignettes: "Writing a rulebook", "Rule reference", "Preparing sites",
  "Method and assumptions"; the README describes the package as built.

## Plots (stage 7)

* One theme, `theme_capacity()` (light or dark), and one palette system,
  `capacity_palette()` and the `scale_*_capacity_*()` scales: eight
  categorical hues in a fixed order validated for colour vision deficiency
  (a ninth category folds into "Other"), a one-hue sequential scale and a
  blue and red diverging scale with a grey midpoint. Zones keep their colour
  from plot to plot. Text is never in a series colour; captions state what
  the figures are.
* Capacity plots: `plot_capacity()` (ranked bars, stacked or faceted),
  `plot_height_profile()`, `plot_distribution()`, `plot_constraints()` (the
  waterfall), `plot_capacity_map()` (sites, grid or areas, per hectare),
  `plot_cumulative()` (the capacity curve), `plot_site()` (plan or
  axonometric) and `autoplot()` (a four-plot dashboard, with patchwork).
* Comparison plots: `plot_comparison()` (dumbbell or change bars),
  `plot_change_map()`, `plot_transitions()` and `plot_attribution()`;
  `plot_sensitivity()`.
* Fixed: envelope geometry (`keep_geometry = TRUE`) labelled storeys wrongly
  when more than one site was built.
* The vignettes show the plots; "Summaries" is now "Summaries and plots".

## Comparing scenarios (stage 6)

* `scenario_set()` and `run_scenarios()`: scenarios run together, the
  baseline in full and the others incrementally from it.
  `read_scenarios()` reads a whole comparison from a YAML manifest.
* `compare_scenarios()`: totals and change; every baseline site's change
  with a reason (`rezoned`, `rule_changed`, `overlay_added`,
  `overlay_removed`, `area_changed`, `neighbour_effect`, `parcel_changed`,
  `unchanged`), with changed parcels apportioned to the baseline's by area;
  zone transitions; by zone, height band, area and grid; land
  reconciliation; and attribution of the change to its drivers (rules,
  zoning, layers, parcels), sequential or Shapley, with the rules driver
  split by each zone, overlay or area whose rules changed. Sites are compared
  by landholding (`scenario(landholding = )`).
* `diff_inputs()`: the rule changes as a table, and the land rezoned, the
  layer land added or removed and the parcels changed as polygons.
  `check_comparison()` reconciles every view.
* Exampleton Plan Change 1 (`exampleton_pc1()`, `rulebook_example(
  "exampleton_pc1")`, and a manifest in `extdata`): a rulebook that
  `extends:` the operative one, a rezoning, a wider flood plain and a
  re-subdivided block. Vignette "Comparing plan changes".
* Boundaries are cut where they cross a distance from the road that a rule
  switches at (`within_frontage`, `beyond_frontage`), so each part takes its
  own rule (capacityengine item 321), for the standards being built. This
  changes Exampleton's figures: MDR's front exemption standard now applies
  its plane behind 20 m on every side boundary.
* Incremental runs: an exclusion layer's change reaches only the sites it
  touches; a run copying every site keeps its storey stack's columns.
* Fixed: `summarise_capacity(by = "area")` replaced the land area with the
  area names.
* The capacityengine converter carries `applies_to_rear_sites: true` (rear
  sites only).
* Gate: operative against PC120 (residential standards) on the Auckland
  tile reproduces capacityengine's change exactly, on every landholding.

## Summaries (stage 5)

* `summarise_capacity()`: capacity by any site column or by zone, storeys,
  height, site size or floor area ratio bands, binding constraint, polygons
  (`areas`), a square grid, or floor area by storey level; measures include
  floor area by use, dwellings, means and medians, floor area ratio, per
  hectare figures and shares. Spatial summaries return `sf`.
* `summary()` of a capacity result: headline, by zone, flags and what limits
  dwellings. `capacity_table()` formats any summary with gt.
* `constraint_breakdown()`: a waterfall from the theoretical maximum (whole
  site, every storey the height allows) to the enabled floor area: storeys
  not reached, setbacks and land, each cap, floor area ratio and maximum
  site floorspace. The steps add up exactly.
* `explain_site()`: one site's rules, boundaries, setbacks at every storey
  with their citations, storeys and dwellings.
* `sensitivity()`: a rule swept through values (or whole rules), with
  incremental reruns.
* `check_capacity()`: reconciliation (parcels, land, storeys against sites,
  uses against floor area) and diagnostics; `unmodelled_report()`: the
  register of rules not modelled.
* Envelopes record `storeys_allowed`; capacity results keep their scenario
  and options.
* Vignettes: "Getting started" and "Summaries".

## Shape, access and the measured front yard (stage 4, part 5)

* `site_shape_factor()`: a zone's `site_shape` rectangle must fit clear of
  the yards, water yards and exclusions for a site to create vacant sites;
  `estimate_capacity()` caps the subdivision paths by it
  (`defaults$site_shape_factor`).
* `find_access_widths()`: the access width of rear sites, from their own
  entrance strip, easements (`scenario(easements = )`) and access lots
  (`scenario(other_parcels = )`); the access width table reads it, and pieces
  of one landholding (`scenario(landholding = )`) share their best access.
* `yard(value_from = "existing_front_setback")`: a front yard set by the
  average setback of the dwellings on the neighbouring sites along the
  street, measured from building outlines (`find_existing_front_setbacks()`,
  `scenario(buildings, streets, neighbours)`); where nothing is measured the
  rule is reported as not applied. The Auckland rulebook's Special Character
  front yard now carries it.
* Morphology `rear_site_sides_as_rear`: a rear site's side boundaries are rear
  boundaries where the plan defines a rear site's yards as rear yards (AUP
  J1); on in the converted rulebooks.
* Height surfaces are banded for all sites in one pass (13 times faster on
  the gate tile); ground tables may match segments by midpoint (`x`, `y`).
* Fixed: an open-ended band of an access width table (or any band table)
  read its upper limit from a field beginning "max" by partial matching.
* plancap now reproduces capacityengine exactly on the gate tile (floor area
  and dwellings on all 2,680 sites, with terrain, height surfaces and the
  measured front yard).

## Terrain and towers (stage 4, part 4)

* Stepped terrain (the default, `defaults$terrain`): each site's ground is a
  plane fitted to its boundaries' ground; a recession plane is measured from
  the ground at its own boundary, taken over runs of near-straight pieces of
  one boundary, and the ground's rise into the site slows the building's gain
  on the plane. `terrain = "flat"` stands the building on one floor at the
  site's mean ground.
* Ground levels may be supplied as tables (`scenario(ground = )`) instead of a
  DEM; a DEM is now sampled along each boundary, not at its midpoint.
* A tower floorplate limit caps storeys above the tower threshold; tower plan
  dimension and separation are counted in the run report as not modelled.
* Reproduces capacityengine with terrain and height surfaces on the gate tile
  to +0.034% of floor area (99.2% of sites exact).

## Reproducing capacityengine (stage 4, part 3)

* On a 2,680-site Auckland tile, on flat ground, plancap reproduces
  capacityengine's floor area to +0.033% (99.4% of sites to 0.01 m2) and its
  dwellings to -0.5% (`data-raw/gate/`).
* `zone_family()`: a family that counts across a boundary only where the
  contiguous area of its zones there is within bounds (rules next to small
  or large open space).
* A zone stating no storey count divides its height into as many
  default-height storeys as fit (20 m: six storeys of 3.33 m).
* A site with no road frontage is left uncapped by the access width table
  and flagged (`access_unmeasured`).

## Heights, surfaces and building form (stage 4, part 2)

* Height overlays follow capacityengine's rules: an override replaces total
  and occupiable height; a cap lowers total height and lowers occupiable
  height only where its value is lower (a cap that bites only the roof
  allowance leaves the storeys); a cap over a zone with no height caps
  nothing. Overlays may carry a `height_conversion` table from mapped total
  height to occupiable height (Auckland's Height Variation Control).
* Height surfaces (rasters, as elevations with a `dem` or as heights above
  ground): a surface covering a whole site caps its height at the lowest
  point; one covering part takes, at each storey, the land the surface is
  too low for.
* Building length and separation cut gaps through the footprint, from the
  height separation starts (`building_separation` may be bands by height).
* Height bonuses are built as a second, incremental envelope and reported in
  the `*_with_bonus` columns.

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
