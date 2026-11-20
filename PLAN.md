# Plan: a jurisdiction-agnostic R package for plan-enabled capacity

Package: **`plancap`** (free on CRAN; no R package of that name on
GitHub). Status (20 November 2026):

- **Stage 0 done.** Gate met: R CMD check green on Windows, macOS and
  Linux (devel, release, oldrel) at github.com/faceteconomics/plancap.
  Codecov upload is non-fatal until Codecov is linked (needs
  CODECOV_TOKEN).

- **Stage 1 built** (rulebook). Schema
  (`inst/schema/rulebook.schema.json`), R constructors, YAML/JSON/XLSX
  I/O (all lossless, tested), validation,
  [`rule_table()`](https://faceteconomics.github.io/plancap/reference/rule_table.md),
  [`set_rule()`](https://faceteconomics.github.io/plancap/reference/set_rule.md)/[`extend_rulebook()`](https://faceteconomics.github.io/plancap/reference/set_rule.md)/`extends:`,
  metres/feet, restricted formulas. Exampleton rulebook hand-written.
  Gate: the three capacityengine bundles convert and validate
  (`data-raw/convert_capacityengine.R`, reports in
  `data-raw/conversion/`): Wellington and Christchurch carry every
  field; Auckland carries all 217 precincts but 13 fields remain, listed
  in its report and unmodelled register (see Stage 1 follow-ups below).

- **Stage 2 built** (site preparation).
  [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md),
  [`scenario_change()`](https://faceteconomics.github.io/plancap/reference/scenario.md),
  [`prepare_sites()`](https://faceteconomics.github.io/plancap/reference/prepare_sites.md)
  with two hashed, session-cached steps (parcel geometry; plan
  geometry); `find_*()` morphology helpers and
  [`site_metrics()`](https://faceteconomics.github.io/plancap/reference/morphology.md);
  [`check_morphology()`](https://faceteconomics.github.io/plancap/reference/check_morphology.md),
  [`plot_morphology()`](https://faceteconomics.github.io/plancap/reference/check_morphology.md).
  Gate: capacityengine’s boundary and adjacency cases ported (rectangle
  classes, winding indifference, thin spike, corner by directions not
  spread, curved street not a corner, internal boundary dissolves,
  far-side zone, carriageway probe, contiguous reserve area) and pass;
  Exampleton prepares as built (9/9 through lots, every rear lot’s leg,
  area conserved, all morphology checks in range); a zoning-only change
  reuses the parcel geometry, a rule-only change reuses both. 222
  expectations.

  Stage 2 design notes for the engine: boundaries have one class (road,
  side, rear) plus tags (reserve, riparian, coastal, lakeside,
  zone_boundary); a rule naming a tag in `boundaries` matches it. Water
  yards should be measured from the water feature (as capacityengine
  item 347), the tag only says the boundary is near water. Corner sites
  keep the ambiguous rear of capacityengine (flagged via `is_corner`).
  Overlay and area membership are long tables with shares, so partial
  coverage (engine item

  368. is resolvable in stage 4. Not yet: incremental (affected-site)
       runs, which belong to stage 3/6; a disk cache.

- **Stage 3 built** (envelope engine).
  [`build_envelopes()`](https://faceteconomics.github.io/plancap/reference/build_envelopes.md):
  rule resolution (zone, then areas and sub-areas, then parameter and
  height overlays; resolved once per distinct combination), storey
  stack, one setback per boundary per storey, single clip with
  reflex-corner wedges, crumbs dropped, caps (coverage and landscaping
  of net site area, floorplate), monotonic stack, variants (max by
  default), water yards from the water, access legs off the ground,
  flat-terrain offsets, `keep_setbacks`, incremental runs from a
  `baseline`. Gate: capacityengine’s hand-worked figures reproduce
  exactly through the converted Auckland rulebook (MHS 433.5/193.5
  clipped, 240/193.5 enabled; THAB 495/331.32/148.92, 748.92 total);
  reflex corners, cul-de-sac fins, convex lots; incremental run equals
  full run. Benchmark (`inst/bench/bench_envelope.R`): linear, ~0.5 ms a
  site to prepare and ~1.6 ms a site to build (12,411 sites in 20 s).
  261 expectations.

  Not yet (stage 4): stepped terrain (capacityengine item 318) and
  boundary runs for ground (item 299); split of boundaries at frontage
  triggers (midpoint test used, item 130); height surfaces and partial
  coverage (item 368); exclusion overlays (hazards, trees) and the
  residential-only kind; FAR and max site floorspace caps; building
  length, separation and gaps; tower controls; impervious only in
  `with_access` ground mode; yield. The real-site check (S039789)
  belongs with the stage 4 tile reproduction, which needs the Auckland
  cadastre.

- **Stage 4, part 1 built** (yield).
  [`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md):
  use split (bands by storey), volumetric / density / hybrid /
  large-site paths (capacityengine items 322, 323, 358, 363, 365, 374,
  377), FAR and max site floorspace capping the stack from the ground
  up, access width, dwellings per site, minor dwellings, area and
  sub-area totals (total_group), entitlements as a floor, bonuses in
  `*_with_bonus` columns (height bonuses not yet evaluated: they need a
  second envelope). Exclusion overlays (all / residential) in the
  engine. 306 expectations. Differences from capacityengine to expect at
  the tile gate: access width is read from road frontage (capacityengine
  measures access from easements, item 259); site shape factor
  (item 324) not yet; access legs are not the “entrance strip” offsets
  of item 374.

- **Stage 4, part 2 built**: height overlays with capacityengine’s cap
  and override semantics (item 297) and a `height_conversion` table
  (HVC, item 68 passthrough between bands); height surfaces, full cover
  caps, partial cover by storey (item 368, covered share 0.99); building
  length and separation gaps, from a height (items 372, 374; converter
  maps `building_gaps_above_m` to separation bands by height); height
  bonuses via an incremental second envelope. Auckland conversion now
  drops 9 fields. 328 expectations.

- **Stage 4 gate, flat ground: met** (20 Nov 2026,
  `data-raw/gate/README.md`). Tile t_011_011 (2,680 sites): floor area
  +0.033%, 99.4% of sites exact to 0.01 m2; dwellings -0.51%, 97.9%
  exact. Every zone but Single House exact. Remaining differences
  traced: 17 irregular special-character lots (boundary classification),
  access width from easements (dwellings), the neighbours’-setback front
  yard (not ported). Fixes made: zone storey height rule,
  area-conditional zone families, unmeasured access uncapped, CfGS
  large-site divisor, precinct name parsing.

- **Stage 4, part 4 built**: stepped terrain (item 318) with boundary
  runs (item 299) and ground planes; ground levels from a DEM (sampled
  along each boundary) or supplied as tables; tower floorplate cap;
  tower dimension and separation flagged. Gate with terrain and height
  surfaces: floor area +0.034%, 99.2% of sites exact
  (data-raw/gate/README.md). 344 expectations.

  **Stage 4, part 5 (next)**: site shape factor (item 324); the measured
  front yard (`value_from`, needs building outlines); access width from
  easements; faster surface sampling (the gate tile takes 158 s with
  surfaces, 34 s without); the 17 to 21 irregular special-character lots
  (classification).

  *(Earlier note)* **Stage 4, part 3**: stepped terrain (item 318) and
  boundary runs (item 299); site shape factor (item 324); tower
  controls; then the tile reproduction: run plancap on a capacityengine
  tile’s own sites, roads, zoning, overlays, DEM and water, compare per
  site against `capacityengine/outputs/region_sites.parquet`
  (floorspace_m2, dwellings, yield_path), and reconcile every difference
  to a known cause (access width from easements, item 259; entrance
  strips, item 374; open-space area tokens such as
  OPEN_SPACE_OVER_2000_WIDE, which plancap families do not yet express).

### Stage 1 follow-ups (for stage 4, engine)

- Auckland Height Variation Control: `class_field`,
  `height_conversion_table`, `passthrough_below/above_m`,
  `between_bands` (mapped total height to occupiable height) and the
  overlay `sub_areas` of the height-sensitive area. Needs an overlay
  “height conversion” construct; design with the engine.
- `value_from: existing_dwelling_setback_average` (SCA front yard set
  from the neighbours): needs a “measured” value source; v1
  net-of-existing work.
- CfGS-fidelity fields (`cfgs_large_site_area_per_dwelling_m2`)
  deliberately not carried.
- Design additions made in stage 1 that the engine must honour:
  `replaces_setbacks` (an override replaces only the named setback
  kinds), `additions`, sub-area `total_group`, plane
  `angle_by_orientation`, `vertical_above`, `max_setback_above`,
  conversion `min_one_dwelling_floor`.
- The Wellington extract (real example data, Q16) is still to do: needs
  the capacity-wellington layers cut to ~1,500 parcels with its
  rulebook. Decisions so far are recorded in section 11.

------------------------------------------------------------------------

## 1. Purpose and scope

An R package that, given **parcel boundaries** and **planning rules**,
estimates the floorspace and dwellings a plan enables on each site, and
then **summarises and plots** the result. It generalises the method
built and tested in `capacityengine` (Auckland, Christchurch,
Wellington) so that any jurisdiction can be modelled by entering its
rules, with no package code written.

In scope:

- A rule model (the “rulebook”) that holds every rule type the capacity
  project has handled, entered by file, by R functions, or by
  spreadsheet.
- Site preparation from any parcel layer: zone splitting, boundary
  classification, frontage, rear sites, zone adjacency, optional
  terrain.
- The 2.5D storey-stack envelope engine and the three yield paths
  (volumetric, density, hybrid).
- Summary, comparison and explanation functions.
- **Scenario comparison (an explicit goal, user 20 Nov 2026).** Build
  two or more scenarios, each a rulebook plus its map layers and
  parcels, where any of those may differ (rules, zone extents, overlay
  or precinct extents, even the parcels), and compare their capacity:
  how much, where, and why it changed. The motivating case is a council
  weighing a plan change against the operative plan, or several options
  against each other. See section 5A.
- A plotting family with one consistent, publication-quality look.
- CRAN-standard documentation, tests, and a pkgdown site; public GitHub
  repo.

Out of scope (stays in `capacityengine` or the council projects):

- Data fetching from LINZ, ArcGIS REST, council servers; region tiling
  and caches; the Shiny explorers; HBA bridges; Auckland-specific
  scripts.
- Feasibility, infrastructure, and market take-up. The package estimates
  **plan-enabled** capacity only, and says so in every print method.

Carried-over principles (these were each earned the hard way in the
project):

1.  **Never invent a rule value.** Every number in a rulebook carries a
    `source` (citation). Missing source is a validation warning, not
    silent.
2.  **Flag, don’t drop.** Every input site appears in every output, with
    flag codes explaining zero or NA results. Totals always reconcile to
    inputs.
3.  **Floor area is the primary output; dwellings are a derived view**
    with the conversion assumptions printed alongside.
4.  **Gross, blank-slate capacity** by default. Net of existing is an
    optional hook if the user supplies existing floorspace or dwellings.
5.  **Alternative standards are modelled as variants**, never merged;
    the user picks the reporting variant (or “max”, “min”, “all”).
6.  **Unmodelled rules are registered** with the direction of effect
    (overstates / understates / either), and reported with the results.

------------------------------------------------------------------------

## 2. Relationship to `capacityengine`

Recommended (Q2): a **clean new package**, written fresh against a
generalised schema, porting the tested algorithms (not the file layout).
`capacityengine` is left alone; later it can depend on the new package
and keep only its NZ data adapters, scenarios and apps. The new
package’s test suite inherits the hand-checked cases (e.g. S039789: 24
setbacks exact; the HIRB formula; the reflex-corner wedges; the
“touching is not overlapping” adjacency cases).

What is ported, generalised:

| capacityengine | New package | Generalisation |
|----|----|----|
| YAML bundle + JSON Schema | `rulebook` S3 object, YAML/JSON/XLSX/R entry | NZ terms renamed to neutral ones (see 3.2); NPS zone keys become user zone keys |
| `build_sites`, `split_sites_by_zone` | [`prepare_sites()`](https://faceteconomics.github.io/plancap/reference/prepare_sites.md) | parcel+title amalgamation becomes an optional `group_by` |
| `classify_boundaries`, frontage, `access_legs` | `classify_boundaries()` | road boundaries from a road layer, OR inferred from gaps / a street centreline layer |
| `apply_zone_adjacency` | `resolve_adjacency()` | unchanged method (probe far side of midpoint) |
| `build_envelope`, `apply_caps`, `enforce_stack_rules` | [`build_envelopes()`](https://faceteconomics.github.io/plancap/reference/build_envelopes.md) | hemisphere-aware orientation rules; units parameter |
| yield paths | `estimate_yield()` | conversion assumptions explicit and required |
| `aggregate_results`, `diff_scenarios` | `summarise_capacity()`, `compare_scenarios()` | much richer, see sections 5A and 6 |
| explorer `site_rules_scene()` | `explain_site()`, `plot_site()` | static ggplot first, interactive optional |

------------------------------------------------------------------------

## 3. The rulebook

### 3.1 Three ways in, one object

``` r

rb <- read_rulebook("exampleton.yaml")          # file (YAML or JSON)
rb <- read_rulebook_xlsx("exampleton.xlsx")     # spreadsheet, for non-R users
rb <- rulebook("Exampleton District Plan", units = "m") |>
  add_zone(zone("MRZ", method = "volumetric",
    height   = height_limit(11, roof_allowance = 1, storeys = 3,
                            source = "MRZ-S1"),
    setbacks = list(setback("road", 1.5, source = "MRZ-S4"),
                    setback(c("side", "rear"), 1, source = "MRZ-S4")),
    planes   = plane(angle = 60, start_height = 4,
                     boundaries = c("side", "rear"), source = "MRZ-S3"),
    coverage = ratio(0.5, source = "MRZ-S5"),
    landscaping = ratio(0.2, source = "MRZ-S6")))
```

- `rulebook_template("new.xlsx")` writes an empty, annotated workbook
  (one sheet per rule family, a citation column on every sheet,
  dropdowns for enumerations). `rulebook_template("new.yaml")` does the
  same in YAML.
- `validate_rulebook(rb)` checks schema (structure), semantics (bands
  contiguous, variants consistent, every zone referenced by the zone
  map, every overlay type has its required fields) and lint (missing
  sources, rules nothing will consume — the riparian lesson).
- `write_rulebook(rb, path)` round-trips to YAML/JSON/XLSX losslessly
  (tested by round-trip property tests).
- `print(rb)` / `summary(rb)` give a readable digest; `rule_table(rb)`
  gives a long tidy table of every rule, zone, value and citation (a
  good appendix table for a report).
- `extend_rulebook(base, changes)` = the scenario mechanism (`extends:`
  in capacityengine): a plan change or sensitivity expressed as a diff.
  `set_rule(rb, zone = "MRZ", "height", 16)` for quick what-ifs.

### 3.2 Rule catalogue (everything handled in the project)

Neutral names first, with the NZ term in brackets. Every rule accepts
`source`, `variant`, `activity_status` and conditions (3.3).

**Height and storeys** -
`height_limit(value, occupiable, roof_allowance, storeys)` — total vs
occupiable height (the HVC lesson: mapped height includes roof form). -
Storey heights: default, ground-floor height, per-zone; storey count
derived as occupiable / intended storeys, never a flat 3 m. -
`no_limit_stand_in` for zones with no height limit, flagged as upper
bound. - Absolute height limits (RL above datum) as well as
above-ground.

**Setbacks (yards)** — by boundary class: `road`, `side`, `rear`,
`internal`, `common`, `coastal`, `riparian`, `lakeside`, `reserve`,
`rail`, plus user-defined classes keyed to a layer. Options:
`above_storey`, `max_value`, `value_from = "existing_average"` (special
character front yard), water yards measured from a water layer.

**Planes** (recession plane / height in relation to boundary / daylight
angle / sky exposure plane): angle, start height, set-in, boundaries,
`orientation_graded` (angle by compass bearing; **hemisphere-aware**),
`on_southern_boundary_of_neighbour` (generalised to `facing`),
exemptions for the front N m or share of depth, datum (ground / boundary
/ site mean), `vertical_above`, step-back above a height.

**Upper-level setbacks**: extra setback above a storey or height, per
class.

**Site ratios**: building coverage, landscaped area, impervious, paved —
each a single value or **bands by site area**; floor area ratio (FAR)
max.

**Building form**: max floorplate, max tower floorplate / dimension,
tower separation, building length, building separation, gaps above a
height, minimum floorplate (enforced in the stack), minimum building
width, site shape factor (min rectangle).

**Density**: site area per dwelling, dwellings per hectare, minimum site
area, vacant site minimum, max dwellings per site, minor dwellings, max
/ min dwellings across an area (precinct totals), large-site rules
(threshold, infrastructure deduction, alternative density), access-width
table (frontage/accessway width → max dwellings), minimum dwelling size.

**Use mix**: residential enabled, business enabled, residential share of
floorspace in mixed zones (with source), max floorspace per site / area.

**Methods**: `volumetric` (storey stack), `density` (rule straight to
dwellings), `hybrid` (both, take the lesser).

**Overlays** (spatial layers that modify rules), with precedence:
`height_cap`, `height_override`, `height_surface` (raster/TIN,
e.g. airport surfaces, viewshafts, sunlight admission planes),
`height_bands` (a mapped height converted via a table, the HVC case),
`exclusion` (subtract geometry: hazards, designations, water yards),
`parameter_override` (edit named zone parameters, e.g. special
character), `flag_only`. Each can be `default_enabled: false` and
switched on in a scenario. Partial coverage: a surface caps only the
part of a site it covers (engine item 368, done properly from the
start).

**Areas** (precinct / sub-precinct / specific control / overlay zone):
`overrides`, `additions`, per-zone overrides, sub-areas keyed by a
field.

**Zone adjacency**: rules that switch on the zone across the boundary
(business yards and planes), with zone families for set membership.

**Conversion**: floorspace → dwellings (dwelling size, circulation and
efficiency allowances, minimum-one-dwelling floor), shown in every
output that reports dwellings.

**Unmodelled rules register**: rule, zones, reason, likely effect of
modelling it (overstates / understates / either), size where known.

### 3.3 Conditions available to any rule

min/max site area; rear sites only / not; within N m of frontage (tested
at segment midpoint, documented) or share of depth; adjacent zone(s) or
not; above storey / height; boundary orientation; variant; activity
status. Conditions that cannot be evaluated (missing layer) follow the
project rule: not applied, counted, and warned with the direction of the
error.

### 3.4 Jurisdiction-neutral details

- Units: metres internally; `units = "ft"` accepted on input and output
  (Q7). Sites must be in a projected CRS; geographic CRS is an error.
- Hemisphere inferred from the CRS / centroid for orientation rules,
  overridable.
- `zone_map`: the jurisdiction’s own zone codes/labels → rulebook zone
  keys (the alias map), with a check that every mapped zone is either
  modelled or listed as unmodelled (no silent zero).

### 3.5 Combining overlapping rules, and rules from other jurisdictions

Full analysis in
[RULES-RESEARCH.md](https://faceteconomics.github.io/plancap/RULES-RESEARCH.md).
In summary:

- **Coverage, landscaping and impervious limits combine as the most
  restrictive, not additively** (as capacityengine does now). A **ground
  budget** adds the paving a development needs (access legs, surface
  parking, outdoor space per dwelling). It has three modes:
  `most_restrictive` (default), `with_access` and `full`. Sites with no
  slack are flagged. A `ground_overlap:` block declares which ground may
  count twice.
- **Seven combination operators**: `cap`, `envelope`, `replace`,
  `floor`, `add`, `multiply`, `composite`. They are evaluated in a fixed
  order: zone → areas → overlays → bonuses → entitlements. Variants: by
  default a site takes the maximum over its permitted variants.
- **Setback profile primitive.** Every rule about distance from a
  boundary becomes d(h) from an origin line (boundary, far side of road,
  road centreline). **Values may be restricted formulas**,
  e.g. `max(3, 0.4*H)` or `road_width*0.4`.
- **New triggers** (stage 2): road width, slope, distance band to a
  layer, corner or through site, site dimensions.
- **New in v1**: GFA definition; unit mix conversion; parking; coverage
  by height; bonuses reported separately; buffer exclusions such as
  trees; minimum floor level.
- **v2** (held as rules and flagged in v1): shadow and sunlight;
  building depth and separation packing; outlook; amalgamation.

------------------------------------------------------------------------

## 4A. Morphology helpers (user request, 20 Nov)

Identifying what each boundary and site *is* comes before any rule can
apply, and every such identification rests on assumptions (how much road
contact makes a frontage, what angle splits side from rear). These get
their own exported family, `find_*()`, so they can be run, inspected,
plotted and corrected on their own, before any capacity run.

| Helper | Identifies | Default assumptions (all overridable) |
|----|----|----|
| [`find_road_frontages()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Boundaries on a road; frontage length per road | Road layer if given, else gap or centreline inference; min road contact 0.5 m; probe distance 25 m to clear carriageways |
| [`find_side_rear()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Side vs rear boundaries | Angle to frontage; tolerance 30°; depth-share rule for ambiguous segments |
| [`find_corner_sites()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Sites on two or more roads at an angle | Corner angle tolerance; min frontage on each road |
| [`find_through_sites()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Sites with frontage on opposite sides | Bearing difference ≥ 135° |
| [`find_rear_sites()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Rear (battle-axe) sites | Frontage below a width threshold or reached only by a leg |
| [`find_access_legs()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Driveways / access legs, and whether they come off net site area | Leg opening 7.5 m max; road contact ≥ 0.5 m; `exclude_from_net_area = TRUE` |
| `find_rights_of_way()` | Shared accessways from an easement layer | Optional layer; width from geometry |
| `find_internal_boundaries()` | Common walls / internal boundaries (unit titles, cross-leases, amalgamated sites) | Shared-edge overlap fraction, never `intersects` |
| [`find_water_boundaries()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Coastal, riparian, lakeside boundaries | Distance to water layer; bank vs centreline |
| `find_reserve_boundaries()` | Boundaries onto open space / reserves | Zone family membership across the boundary |
| `find_boundary_runs()` | Near-straight pieces of one boundary treated as one | Merge angle 5° |
| [`site_metrics()`](https://faceteconomics.github.io/plancap/reference/morphology.md) | Area, depth, width, frontage width, compactness, largest inscribed rectangle (site shape factor) | — |

How assumptions are held:

``` r

morphology_defaults()                       # package defaults, documented
rb <- set_morphology(rb, corner_angle_deg = 25, access_leg_max_width_m = 6)
sites <- prepare_sites(parcels, zoning, rulebook = rb,
                       morphology = list(min_road_contact_m = 1))  # run override
```

Precedence: run argument \> rulebook `morphology:` block \> package
default. The values actually used are stored on the result, so every run
says which definitions it applied. Each helper returns the
classification **and the evidence** (contact length, angle, probe hit),
so a wrong call can be traced.

Checking tools:

- `plot_morphology(sites, area = bbox)` — boundaries coloured by class,
  rear sites and access legs hatched, corners marked. The way to eyeball
  a new jurisdiction’s cadastre before trusting a run.
- `check_morphology(sites)` — shares of each class against plausible
  ranges (the project’s 19% corner-site share was a warning sign worth
  automating); unclassified segments; inward-normal failures.
- `override_boundaries(sites, segment_id, class)` — manual correction
  table, applied reproducibly (kept as data, not edits to geometry).

## 4. Site preparation

``` r

sites <- prepare_sites(parcels, zoning,
  zone_field = "ZONE", roads = road_parcels,      # or streets = centrelines
  water = rivers, group_by = NULL, terrain = NULL, rulebook = rb)
```

Steps, each also exported on its own:

1.  `clean_parcels()` — validity, drop slivers (flagged), drop
    road/rail/water parcels by a user-supplied filter, projected-CRS
    check.
2.  `split_sites_by_zone()` — partition-safe (no 50/50 drop).
3.  `classify_boundaries()` — segments; road / side / rear / internal by
    adjacency, road contact and frontage; rear sites and access legs;
    corner sites; inward normals from the geometry, not vertex order.
4.  `resolve_adjacency()` — zone across each boundary (pass the WHOLE
    zoning layer, including open space).
5.  `attach_overlays()` — area/length overlap fractions, never
    `intersects`.
6.  `attach_terrain()` (optional, `terra`) — per-segment ground datum.

Result is a `cap_sites` object (sf + segments table) that can be cached
and reused across rule scenarios, because it does not depend on rule
values (only on the zoning/overlay layers). That split is what made
Auckland’s re-runs fast.

For scenarios (section 5A) the preparation is split in two, so a plan
change that only redraws zones does not redo the expensive geometry:

- **Parcel geometry** (steps 1 and 3, plus terrain and the morphology
  helpers): depends only on parcels, roads, water and terrain.
- **Plan geometry** (steps 2, 4 and 5): depends on the zoning, overlay
  and precinct layers.

Each part is stored with a hash of its inputs, and a scenario reuses any
part whose inputs are unchanged.

Performance rules baked in: no per-site loops with GEOS calls; STRtree
joins; clip lookup geometry to the working extent; chunked runs with
optional parallelism (`mirai` or `future`, Q10). Target: 50k sites in
minutes on a laptop; benchmark script in `inst/bench/`.

------------------------------------------------------------------------

## 5. Engine and results

``` r

cap <- estimate_capacity(sites, rb, variant = "standard",
                         conversion = conversion(dwelling_size = 90))
```

[`estimate_capacity()`](https://faceteconomics.github.io/plancap/reference/estimate_capacity.md)
=
[`build_envelopes()`](https://faceteconomics.github.io/plancap/reference/build_envelopes.md) +
`estimate_yield()`. Envelope method as in capacityengine: loop storeys,
vectorise sites, reduce setbacks/planes/upper-level rules to one
required setback per segment, three GEOS calls a storey, test each
storey at its ceiling, then caps (coverage as share of SITE area, FAR,
floorplate), then stack rules.

The result is a `cap_result` S3 object:

| Slot | Content |
|----|----|
| `sites` | sf, one row per input site: zone, area, method, height, storeys, footprint, GFA, residential GFA, business GFA, dwellings, binding constraint, flags |
| `storeys` | tibble, site × storey: level, height, floor area, binding constraint |
| `segments` | optional (`keep_setbacks = TRUE`): segment × storey setback, winning rule, citation |
| `rulebook`, `conversion`, `variant` | what produced it |
| `meta` | package version, run time, input hashes, warnings tally |

Tidy accessors: `as_tibble(cap)`, `sf::st_as_sf(cap)`,
`cap_storeys(cap)`, `cap_flags(cap)`. `print(cap)` gives a short
headline with the “plan-enabled, gross, blank-slate” caveat and the
conversion assumption.

Binding constraint per storey (height / plane / setback / coverage / FAR
/ floorplate / density / overlay) is recorded, because it powers the
most useful summary and plot (which rule is doing the work).

------------------------------------------------------------------------

## 5A. Scenarios and plan-change comparison (explicit goal)

### What a scenario is

A **scenario** is everything that determines capacity: a rulebook, the
map layers it refers to (zoning, overlays, precincts), the parcels,
roads and water, and the run options. Two scenarios may differ in any of
these:

| What differs | Example | How it is handled |
|----|----|----|
| Rule values | Height in MRZ from 11 m to 16 m | Rulebook `extends:` the baseline’s |
| New or removed zones or rules | A new “Terraced Housing” zone | New zone keys; comparison by zone transition |
| Zone extents | Rezoning a walkable catchment | A different zoning layer |
| Overlay or precinct extents | A new flood hazard map; a precinct enlarged | Different overlay or precinct layers |
| New overlays or qualifying matters | A heritage overlay added | Rulebook adds the overlay; scenario adds its layer |
| Parcels | A structure plan’s new lots; amalgamations; road widening | A different parcel layer; comparison by crosswalk or common geography |

``` r

base <- scenario("Operative", rulebook = rb_operative,
                 layers = list(parcels = parcels, roads = roads, zoning = zoning_op,
                               height_areas = ha, flood_hazard = fh, precincts = pr))

# A plan change starts from the baseline and says only what changes
pc1 <- scenario_change(base, "PC1 as notified",
                       rulebook = read_rulebook("pc1.yaml"),   # extends: operative.yaml
                       layers = list(zoning = zoning_pc1))      # other layers inherited

scen <- scenario_set(base, pc1, pc1_option_b)    # the first is the baseline
res  <- run_scenarios(scen)                      # shares and reuses work
cmp  <- compare_scenarios(res)                   # each against the baseline
summary(cmp); plot_change_map(cmp); plot_attribution(cmp)
```

Scenarios can also be written as a **manifest file** (YAML: name,
rulebook path, layer paths, which scenario it changes), so a council’s
comparison is one reproducible file:
`read_scenarios("pc1-options.yaml")`.

### Where it fits in the pipeline

    inputs ──► A. parcel geometry ──► B. plan geometry ──► C. rule resolution ──► D. envelope + yield ──► E. results ──► F. comparison
              (parcels, roads,        (zoning, overlay,     (rulebook: each        (per site)                          (two or more
               water, terrain;         precinct layers:      site's effective                                           scenarios)
               morphology)             zone split,           parameters)
                                       adjacency, overlays)

Each step’s output is keyed by a hash of its inputs. A scenario
recomputes only the steps whose inputs changed:

| Change | A | B | C | D |
|----|----|----|----|----|
| Rule values only | reuse | reuse | redo (affected zones) | redo (affected sites) |
| Zoning or overlay extents | reuse | redo (affected sites) | redo (affected sites) | redo (affected sites) |
| Parcels | redo (changed parcels) | redo (changed parcels) | redo | redo |

**Incremental runs (affected sites only).** A site’s result can change
only if its parcel geometry changed, its zone changed, its overlay or
area membership changed, the rules of its zone, overlays or areas
changed (found by diffing the two rulebooks’ rule tables), or a
neighbour’s zone changed where a rule depends on the zone across the
boundary. Everything else is copied from the baseline. For a
region-scale plan change that touches a tenth of sites this is roughly
ten times faster. A test checks that the incremental run equals a full
run exactly.

### Comparing when the geography differs

- **Same parcels:** a per-site difference, joined on site id.
- **Different parcels:** three levels, all reported:
  1.  *Matched sites*: parcels whose geometry is unchanged (normalised
      geometry hash, or the same id with at least 99% overlap) compare
      directly.
  2.  *Crosswalk*: changed parcels are linked by area overlap (many to
      many), and capacity is apportioned by area share, giving a change
      per baseline parcel.
  3.  *Common geography*: the user’s areas (suburbs, statistical areas),
      a square or hex grid, or the extent of the change. Always valid,
      and the totals reconcile.
- **Different zone keys:** a **transition table** of land area and
  capacity from each baseline zone to each scenario zone (MRZ → THAB,
  new zones, removed zones). This is the natural way to read a rezoning.
- **Land reconciliation:** total land per scenario, and how it differs
  (roads vested, reserves created, parcels added or removed). Flag,
  don’t drop: sites present in only one scenario are listed, never
  silently left out.

### Why did capacity change? (attribution)

A plan change usually moves several things at once.
`compare_scenarios()` splits the total change (and each area’s change)
into its **drivers**: rule values, zone extents, overlay and precinct
extents, and parcels. It does this by running intermediate scenarios
that switch one driver at a time:

- **Sequential** (default; one extra run for each driver): apply the
  drivers in a stated order. Cheap, but the split depends on the order.
- **Shapley** (optional; 2^k runs for k drivers, so 16 at most): average
  over every order, so the split does not depend on order. Practical
  because incremental runs only recompute affected sites.

For a rule-only change it also splits the change by individual rule
(from the rule table diff), e.g. “+38% from the height increase, −6%
from the new recession plane”. The drivers always sum to the total
change.

### What a comparison returns

A `cap_comparison` object:

- totals for every scenario, with absolute and percentage change against
  the baseline;
- change by zone transition, by area or grid cell, and by height band;
- site-level changes (sf) for matched sites and crosswalked parcels,
  each with a **reason code**: `rezoned`, `rule_changed`,
  `overlay_added`, `overlay_removed`, `area_changed`, `parcel_changed`,
  `neighbour_effect`;
- the attribution table;
- an input diff (`diff_inputs()`): the rule changes as a table, and the
  map changes as polygons (land rezoned, overlay added or removed,
  parcels changed);
- reconciliation checks (`check_comparison()`).

Summaries and plots built on it: `summary(cmp)`, `plot_comparison()`
(dumbbell or bars by zone, area or height band), `plot_change_map()`
(diverging colours on sites, grid or areas), `plot_transitions()`
(zone-to-zone flows of land and capacity), `plot_attribution()`
(waterfall of drivers), and `plot_height_profile(cmp)` (each scenario’s
floor area by storey, overlaid).

More than two scenarios: each is compared with the baseline by default;
`compare_scenarios(res, pairs = ...)` adds other pairs; a
scenario-by-measure table summarises all of them.

### Example data

Exampleton gets a worked plan change, **“Exampleton PC1”**, built to
exercise every kind of difference:

- a rulebook that `extends:` the operative one (MDR height 12 → 16 m, a
  new “Terraced Housing” zone);
- a zoning layer upzoning the blocks within 400 m of the station;
- an enlarged flood overlay;
- one block re-subdivided into new lots.

It is the example for the “Comparing plan changes” vignette and the gate
test for stage 6.

------------------------------------------------------------------------

## 6. Summaries

Design goal: one verb with a `by` argument, sensible defaults, tidy
output, and a pretty table on demand.

``` r

summary(cap)                                   # headline + by zone
summarise_capacity(cap, by = "zone")           # tibble
summarise_capacity(cap, by = c("zone", "height_band"),
                   measures = c("gfa", "dwellings", "sites", "land_area"))
summarise_capacity(cap, by = "area", areas = suburbs, area_id = "name")
summarise_capacity(cap, by = "storeys")
capacity_table(x)                              # gt table, formatted, sourced
```

`by` accepts: any site column (zone, method, variant, overlay flags),
derived bins (`height_band`, `storeys`, `site_size_band`, `fsr_band`),
spatial units (`areas =` polygons, assigned by majority with partition
safety; or `grid = 500` for a hex/square grid), and
`binding_constraint`.

Measures: sites, land area, footprint, GFA (total / residential /
business), dwellings, mean & median per site, FAR achieved, share of
total, plus “density” measures per hectare of land.

Other summary functions:

- `constraint_breakdown(cap)` — floor area lost to each rule, in
  sequence from a theoretical maximum (zoned land × height) down to
  enabled. Feeds the waterfall plot.
- `compare_scenarios()`: scenario differences, including where the
  zones, overlays or parcels differ. See section 5A.
- `sensitivity(sites, rb, rule = "MRZ$height", values = c(11, 14, 16))`
  — sweeps a rule and returns a tidy table.
- `explain_site(cap, site_id)` — boundary-by-boundary table: class,
  length, setback per storey, winning rule and citation; caps; binding
  constraint.
- `unmodelled_report(rb)` — the register as a table, for any report.
- `check_capacity(cap)` — reconciliation and diagnostics (sites in =
  sites out, zero-capacity sites by reason, flags tally, suspicious
  values).

------------------------------------------------------------------------

## 7. Plots

All ggplot2, all return ggplot objects (so users can add layers), one
theme (`theme_capacity()`) and one palette system, colour-blind safe,
light/dark variants. Labels auto-formatted (m², k / M, %). Captions
auto-state “Plan-enabled gross capacity; dwellings at X m² per
dwelling”.

| Function | What it shows |
|----|----|
| `plot_capacity(cap, by = "zone", measure = "gfa")` | Ranked horizontal bars; `fill =` second variable for stacks; `facet =` |
| `plot_height_profile(cap, by = "zone")` | Floorspace by storey / height band: a “skyline” histogram of where capacity sits vertically |
| `plot_distribution(cap, measure = "dwellings")` | Per-site distribution (ridgeline / histogram) by zone |
| `plot_constraints(cap)` | Waterfall from theoretical max to enabled, by rule; or share of storeys bound by each rule, by zone |
| `plot_capacity_map(cap, measure, grid = 250)` | Choropleth on sites, hex grid or user areas; basemap optional (`maptiles`) |
| `plot_comparison(cmp, by = "zone")` | Dumbbell or diverging bars between scenarios |
| `plot_change_map(cmp)` | Where capacity rises and falls (diverging colours on sites, grid or areas) |
| `plot_transitions(cmp)` | Zone-to-zone flows of land and capacity |
| `plot_attribution(cmp)` | Waterfall of what drove the change (rules, zoning, overlays, parcels) |
| `plot_sensitivity(sens)` | Line/step chart of a rule sweep |
| `plot_cumulative(cap)` | Capacity curve: cumulative dwellings vs share of land, sites ranked |
| `plot_site(cap, site_id, view = "plan" / "axo")` | Single site: parcel, setback strips, storey footprints in plan; axonometric stack (ggplot polygons, no 3D dependency) |
| `autoplot(cap)` | Sensible default dashboard (patchwork of 4) |

Optional interactive layer (Suggests only): `view_capacity_3d(cap)` with
`mapgl` (MapLibre extrusions) — the visual language already proven in
the capacity viewer. Q11 decides whether this is v1 or later.

The plotting look gets its own design pass at stage 6 with rendered
examples reviewed before release (house rule: verify against the
rendered output, not the code).

------------------------------------------------------------------------

## 8. Example data and documentation

**Example data (Q5).** A synthetic town, “Exampleton”: ~2,000 parcels
with roads, five zones, a height overlay, a precinct, a river, an
exclusion, plus its rulebook in YAML and XLSX. Synthetic means no
licence questions and it can be built to exercise every rule (corner
sites, rear lots, adjacency, bands). Optionally a small real NZ extract
(LINZ data is CC BY 4.0) as a second, realistic dataset.

**Documentation (CRAN standard):**

- roxygen2 on every exported function, with runnable examples on
  Exampleton (fast, \< 5 s each).
- Vignettes:
  1.  *Getting started* — parcels to plots in ten lines.
  2.  *Writing a rulebook* — the three entry routes, validation,
      citations.
  3.  *Rule reference* — every rule type, a diagram each, how it is
      computed.
  4.  *Preparing sites* — boundary classes, adjacency, terrain,
      pitfalls.
  5.  *Summaries and plots* — gallery.
  6.  *Scenarios, sensitivity and comparison*.
  7.  *Adding a new jurisdiction* — worked example from plan text to
      results.
  8.  *Method and assumptions* — what “plan-enabled” means, what it is
      not, the unmodelled register, validation against published
      studies.
- pkgdown site (GitHub Pages), README with badges, NEWS.md, CITATION,
  CONTRIBUTING, Code of Conduct, issue templates (incl. “new
  jurisdiction”).
- `inst/rulebooks/` holds contributed rulebooks; the Auckland,
  Christchurch and Wellington bundles converted as worked, real examples
  (Q6).

**Quality:** testthat 3e (port the ~1,000 expectations that apply), covr
target \> 85%, R CMD check clean (0/0/0) on GitHub Actions for Windows,
macOS, Linux × release/devel/oldrel, lintr, `urlchecker`, `spelling`.
Benchmarks guard against quadratic regressions.

------------------------------------------------------------------------

## 9. Dependencies

Imports (lean): `sf`, `geos`, `wk`, `dplyr`, `tibble`, `vctrs`, `rlang`,
`cli`, `yaml`, `jsonlite`, `jsonvalidate`, `ggplot2`, `scales`.
Suggests: `terra` (terrain, surfaces), `readxl`/`openxlsx2` (XLSX
rulebooks), `gt` (tables), `patchwork` (autoplot), `ggridges`,
`maptiles`/`tidyterra` (basemaps), `mapgl` (3D), `mirai` (parallel),
`arrow`/`sfarrow` (caching), `testthat`, `knitr`, `rmarkdown`/`quarto`.
Everything optional is checked with
[`rlang::check_installed()`](https://rlang.r-lib.org/reference/is_installed.html).

------------------------------------------------------------------------

## 10. Stages and gates

| Stage | Deliverable | Gate |
|----|----|----|
| 0 | Name, repo, skeleton (usethis), CI, licence, Exampleton data | CI green on 3 OSes |
| 1 | Rulebook: schema, R constructors, YAML/JSON I/O, validation, print/rule_table | Auckland/CHC/WCC bundles convert and validate; round-trip tests |
| 2 | Site preparation, split into parcel geometry and plan geometry, each hashed; [`scenario()`](https://faceteconomics.github.io/plancap/reference/scenario.md) object | Ported boundary/adjacency tests pass; Exampleton prepared; a zoning-only change reuses the parcel geometry |
| 3 | Envelope engine; accepts prepared parts; affected-site runs | Hand-checked cases reproduce exactly (S039789 etc.); benchmark |
| 4 | Yield paths, overlays, areas, variants, conversion | A capacityengine region tile reproduces to the m² |
| 5 | Summaries, sensitivity, explain_site | Reconciliation checks; vignettes 1, 5 draft |
| 6 | **Scenarios and comparison**: [`scenario_change()`](https://faceteconomics.github.io/plancap/reference/scenario.md), `scenario_set()`, manifests, `run_scenarios()`, `compare_scenarios()`, crosswalk, transitions, attribution, `diff_inputs()`; Exampleton PC1 | On Exampleton PC1: an incremental run equals a full run; drivers sum to the total change; land reconciles. On Auckland: operative vs PC120 matches capacityengine’s difference on a tile. “Comparing plan changes” vignette drafted |
| 7 | Plots (including comparison plots) and a theme design pass | Rendered gallery reviewed by you |
| 8 | XLSX template entry, new-jurisdiction vignette, docs, pkgdown | A fresh jurisdiction entered from the template end to end |
| 9 | Release: public repo, pkgdown live, (CRAN submission if Q8) | R CMD check 0/0/0; you sign off |

The reproducibility gate at stage 4 is the main safeguard: the new
package must match `capacityengine` on the same inputs before it is
trusted. Stages 2 and 3 are designed from the start for scenarios
(hashed, reusable parts and affected-site runs), because adding that to
a finished engine would mean rewriting it.

------------------------------------------------------------------------

## 11. Decisions (20 November 2026)

| \# | Question | Decision |
|----|----|----|
| Q1 | Name | `plancap` |
| Q2 | Relation to capacityengine | Clean new package; port algorithms and tests; capacityengine untouched, may depend on plancap later |
| Q2a | Morphology | Dedicated `find_*()` helpers with defaults, overridable (section 4A) |
| Q3 | Rule entry | All three: YAML/JSON, R constructors, XLSX template |
| Q4 | Licence | MIT |
| Q5 | Example data | Synthetic “Exampleton” + small real NZ extract (LINZ CC BY 4.0) |
| Q6 | NZ rulebooks | Ship Auckland, Christchurch, Wellington as dated worked examples in `inst/rulebooks/` |
| Q7 | Units | Metres internally; feet / sq ft accepted on input and output |
| Q8 | CRAN | CRAN-standard (0/0/0, full docs) on GitHub first; submission decided after v1 |
| Q9 | GitHub owner | faceteconomics (you may need to create the empty repo; I push) |
| Q10 | Parallel | In v1, `mirai` chunked runs |
| Q11 | Interactive 3D | In v1, `mapgl` (Suggests) |
| Q12 | Net of existing | In v1, when existing floorspace / dwellings are supplied |
| Q13 | Terrain | In v1, `terra` (Suggests) |
| Q14 | Plot style | Neutral, themeable default; optional `theme_facet()` |
| Q15 | Morphology defaults | Held in the rulebook, overridable per run |
| Q19 | Coverage vs landscaping | Most restrictive, not additive; ground budget default mode `most_restrictive` (paving = 0, matches capacityengine); `with_access` and `full` opt-in; no-slack sites flagged |
| Q20 | Variants | Site result = max over permitted variants; every variant kept |
| Q21 | Bonuses | Reported in separate `*_with_bonus` columns; base figure has no bonus |
| Q22 | Shadow / sunlight | v2; v1 holds the rule and flags affected sites |

Consequences for the stages: terrain and morphology move into stage 2;
net-of-existing into stage 4; parallel runs into stage 3; `mapgl` view
into stage 6; the XLSX template into stage 1 (it shares the schema).

Q16 \| Real extract \| Wellington slice (~1,500 parcels with corner
sites, rear lots, a stream and at least two zones), with the WCC
rulebook; LINZ CC BY 4.0 + WCC attribution \|  
Q17 \| Author \| James Stewart (`aut`, `cre`, `cph`) \|  
Q18 \| Auckland rulebook \| Operative AUP only \|  
Q23 \| Scenario comparison \| An explicit project goal (section 5A); its
own stage (6); stages 2 and 3 designed for it \|  
Q24 \| Comparing different parcels \| Default: common areas or grid
(always reconcile) plus per-site change where parcels are unchanged;
crosswalk available \|  
Q25 \| Attribution \| Sequential by default (one run per driver);
Shapley optional \|  
Q26 \| Scenario manifests \| YAML manifest as well as R \|  
Q27 \| Auckland PC120 \| Converted as a test-only rulebook for the stage
6 gate; not shipped \|

All open questions are now settled; stage 0 can start.
