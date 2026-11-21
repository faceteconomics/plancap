# Changelog

## plancap 0.0.0.9000

### Shape, access and the measured front yard (stage 4, part 5)

- [`site_shape_factor()`](https://faceteconomics.github.io/plancap/reference/site_shape_factor.md):
  a zone’s `site_shape` rectangle must fit clear of the yards, water
  yards and exclusions for a site to create vacant sites;
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md)
  caps the subdivision paths by it (`defaults$site_shape_factor`).
- [`find_access_widths()`](https://faceteconomics.github.io/plancap/reference/find_access_widths.md):
  the access width of rear sites, from their own entrance strip,
  easements (`scenario(easements = )`) and access lots
  (`scenario(other_parcels = )`); the access width table reads it, and
  pieces of one landholding (`scenario(landholding = )`) share their
  best access.
- `yard(value_from = "existing_front_setback")`: a front yard set by the
  average setback of the dwellings on the neighbouring sites along the
  street, measured from building outlines
  ([`find_existing_front_setbacks()`](https://faceteconomics.github.io/plancap/reference/find_existing_front_setbacks.md),
  `scenario(buildings, streets, neighbours)`); where nothing is measured
  the rule is reported as not applied. The Auckland rulebook’s Special
  Character front yard now carries it.
- Morphology `rear_site_sides_as_rear`: a rear site’s side boundaries
  are rear boundaries where the plan defines a rear site’s yards as rear
  yards (AUP J1); on in the converted rulebooks.
- Height surfaces are banded for all sites in one pass (13 times faster
  on the gate tile); ground tables may match segments by midpoint (`x`,
  `y`).
- Fixed: an open-ended band of an access width table (or any band table)
  read its upper limit from a field beginning “max” by partial matching.
- plancap now reproduces capacityengine exactly on the gate tile (floor
  area and dwellings on all 2,680 sites, with terrain, height surfaces
  and the measured front yard).

### Terrain and towers (stage 4, part 4)

- Stepped terrain (the default, `defaults$terrain`): each site’s ground
  is a plane fitted to its boundaries’ ground; a recession plane is
  measured from the ground at its own boundary, taken over runs of
  near-straight pieces of one boundary, and the ground’s rise into the
  site slows the building’s gain on the plane. `terrain = "flat"` stands
  the building on one floor at the site’s mean ground.
- Ground levels may be supplied as tables (`scenario(ground = )`)
  instead of a DEM; a DEM is now sampled along each boundary, not at its
  midpoint.
- A tower floorplate limit caps storeys above the tower threshold; tower
  plan dimension and separation are counted in the run report as not
  modelled.
- Reproduces capacityengine with terrain and height surfaces on the gate
  tile to +0.034% of floor area (99.2% of sites exact).

### Reproducing capacityengine (stage 4, part 3)

- On a 2,680-site Auckland tile, on flat ground, plancap reproduces
  capacityengine’s floor area to +0.033% (99.4% of sites to 0.01 m2) and
  its dwellings to -0.5% (`data-raw/gate/`).
- [`zone_family()`](https://faceteconomics.github.io/plancap/reference/zone_family.md):
  a family that counts across a boundary only where the contiguous area
  of its zones there is within bounds (rules next to small or large open
  space).
- A zone stating no storey count divides its height into as many
  default-height storeys as fit (20 m: six storeys of 3.33 m).
- A site with no road frontage is left uncapped by the access width
  table and flagged (`access_unmeasured`).

### Heights, surfaces and building form (stage 4, part 2)

- Height overlays follow capacityengine’s rules: an override replaces
  total and occupiable height; a cap lowers total height and lowers
  occupiable height only where its value is lower (a cap that bites only
  the roof allowance leaves the storeys); a cap over a zone with no
  height caps nothing. Overlays may carry a `height_conversion` table
  from mapped total height to occupiable height (Auckland’s Height
  Variation Control).
- Height surfaces (rasters, as elevations with a `dem` or as heights
  above ground): a surface covering a whole site caps its height at the
  lowest point; one covering part takes, at each storey, the land the
  surface is too low for.
- Building length and separation cut gaps through the footprint, from
  the height separation starts (`building_separation` may be bands by
  height).
- Height bonuses are built as a second, incremental envelope and
  reported in the `*_with_bonus` columns.

### Capacity (stage 4, part 1)

- [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md)
  turns envelopes into floor area (split between residential and
  business by each zone’s use and residential share, by storey where it
  changes) and dwellings, by volumetric, density, hybrid and large-site
  paths; then floor area ratio and maximum site floorspace (capping the
  stack from the ground up), no dwellings without a buildable envelope
  or on land overlays remove, dwellings per site, the access width cap,
  minor dwellings, area totals (including sub-areas sharing a total),
  and entitlements as a floor. Bonuses are reported in `*_with_bonus`
  columns.
- Exclusion overlays: `removes: all` takes land off the buildable
  ground; `removes: residential` keeps floor area over it out of
  dwellings.

### The envelope engine (stage 3)

- [`build_envelopes()`](https://faceteconomics.github.io/plancap/reference/build_envelopes.md)
  builds each site’s storey stack: storeys at the zone’s own storey
  height, each tested at its ceiling; one setback per boundary per
  storey (the deepest any applicable rule asks); a single clip with
  reflex corners filled; coverage and landscaping as shares of net site
  area; floorplate caps; a stack that never widens and ends below the
  minimum floorplate. Water yards are measured from the water; access
  legs come off the buildable ground.
- Rules are resolved per site: zone, then precincts and sub-areas (which
  replace), then parameter overlays and height overlays. A change
  replaces whole fields such as `height`, and replaces only the setback
  kinds it names.
- Alternative standards are built separately and each site takes the
  most enabling (or the one named by `variant_choice`).
- `keep_setbacks = TRUE` returns, for every boundary at every storey,
  the setback applied and the rule and citation that set it.
- Incremental runs: given a `baseline`, sites whose inputs are unchanged
  are copied; the result equals a full run.
- Reproduces capacityengine’s hand-worked envelope figures through the
  converted Auckland rulebook.

### Scenarios and site preparation (stage 2)

- [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md)
  bundles a rulebook with its parcels, roads, zoning and other layers;
  [`scenario_change()`](https://faceteconomics.github.io/plancap/reference/scenario.md)
  describes a plan change as what differs from a base scenario.
- [`prepare_sites()`](https://faceteconomics.github.io/plancap/reference/prepare_sites.md)
  turns a scenario into sites in two cached steps: parcel geometry
  (depends only on parcels, roads, water, centrelines and ground) and
  plan geometry (zoning, overlays, areas). A rule-only change reuses
  both; a zoning change reuses the first.
- Morphology helpers, each returning its evidence:
  [`find_road_frontages()`](https://faceteconomics.github.io/plancap/reference/morphology.md),
  [`find_side_rear()`](https://faceteconomics.github.io/plancap/reference/morphology.md),
  [`find_corner_sites()`](https://faceteconomics.github.io/plancap/reference/morphology.md),
  [`find_through_sites()`](https://faceteconomics.github.io/plancap/reference/morphology.md),
  [`find_rear_sites()`](https://faceteconomics.github.io/plancap/reference/morphology.md),
  [`find_access_legs()`](https://faceteconomics.github.io/plancap/reference/morphology.md),
  [`find_water_boundaries()`](https://faceteconomics.github.io/plancap/reference/morphology.md),
  [`find_road_widths()`](https://faceteconomics.github.io/plancap/reference/morphology.md)
  and
  [`site_metrics()`](https://faceteconomics.github.io/plancap/reference/morphology.md).
  Boundaries have a class (road, side, rear) and tags (reserve,
  riparian, coastal, lakeside, zone boundary).
- Sites crossed by a zone boundary are split (slivers merged, unzoned
  remainders kept); the zone across each boundary is found by probing
  outward, across the carriageway for road frontages.
- [`check_morphology()`](https://faceteconomics.github.io/plancap/reference/check_morphology.md)
  compares classification shares with usual ranges;
  [`plot_morphology()`](https://faceteconomics.github.io/plancap/reference/check_morphology.md)
  draws them.

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
