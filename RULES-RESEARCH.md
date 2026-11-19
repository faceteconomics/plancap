# Rules from other jurisdictions, and how overlapping rules combine

20 November 2026. Feeds PLAN.md section 3. Figures marked (v) were confirmed
in a source this session; figures marked (k) are from general knowledge and
must be checked against the instrument before any rulebook uses them.

---

## Part A. How overlapping rules combine

### A1. Coverage, landscaping, impervious and paving: the answer

The engine today (`capacityengine/R/envelope_caps.R`, `apply_caps()`) takes,
for each storey, the **least** of:

- the clipped geometry,
- coverage × net site area,
- (1 − landscaping) × net site area,
- maximum floorplate.

So it takes the **most restrictive** one, as you thought ("the greater of" the
restrictions). Impervious and paved limits are read but not applied.

**That is the right rule, and adding them would be wrong.** But it has one
gap. The reasoning follows.

At ground level a site splits into parts that do not overlap. Call them
building footprint F, paving P (driveways, parking, patios) and landscaping L,
with F + P + L ≤ A. Each rule is a limit on some of those parts:

| Rule | Limit | Limit on footprint |
|---|---|---|
| Coverage max *c* | F ≤ cA | F ≤ cA |
| Landscaping min *l* | L ≥ lA | F ≤ (1 − l)A − P |
| Impervious max *i* (building counts as impervious) | F + P ≤ iA | F ≤ iA − P |
| Paving max *p* | P ≤ pA | none, unless P is required |
| German GRZ II (k) | F + ancillary ≤ min(1.5 GRZ, 0.8)A | F ≤ that − ancillary |

Maximum footprint = **the least of those limits**. Adding them would count
land twice. Example: 50% coverage and 30% landscaping do not leave 20% (that
is what adding them gives). The 30% of landscaping fits inside the 50% left
unbuilt, so coverage alone decides the result: 50%.

**The gap is the P term.** The engine sets P = 0, so it assumes the
development needs no paving. Where *c* + *l* is close to 1 that is wrong. Take
MHU in Auckland with *c* = 0.5 and *l* = 0.3, and 0.2 of slack. A rear site
whose access leg is 8% of the site is fine. But a zone with *c* = 0.6 and
*l* = 0.4 has no room left for a driveway, so the "most restrictive" rule
overstates capacity on any site that needs vehicle access. It matters most in
three cases:

- rear sites (the access leg is paved, unless it is taken out of net site area, as item 301 already does);
- plans with minimum parking (US, parts of Australia), where surface parking is P;
- impervious limits, which the engine skips today for exactly this reason.

**Proposal: a "ground budget" with three modes.**

| Mode | P | Use |
|---|---|---|
| `most_restrictive` (default, matches the engine today) | 0 | Plan-enabled upper bound; reconciles with capacityengine |
| `with_access` | measured access leg / driveway + a per-dwelling allowance for parking and manoeuvring if the rulebook sets one | More honest where parking is required or *c* + *l* ≈ 1 |
| `full` | Adds ground that each dwelling needs (outdoor living space, private open space, open space ratio) | Ground-floor housing; solved as a small linear programme per site because dwellings depend on floor area |

Every run reports which mode it used, and flags sites where *c* + *l* +
P_required > 1. Those sites have no slack, and their capacity depends on the
mode.

**The rulebook must also declare which ground may count twice**, because
plans differ:

- Can outdoor living space count as landscaping? It often can, and some plans say no.
- Does landscaping on a podium or roof count? Not in the AUP; often yes in Sydney landscaping rules. Deep soil never does.
- Is deep soil part of landscaping? (Sydney ADG: yes. Deep soil also bans basements beneath it.)
- Are there sub-area requirements, such as "50% of the front yard landscaped"? These only limit P inside the yard, but they can rule out a front driveway.
- Does a covered deck or carport count as coverage?

These go in a `ground_overlap:` block, with defaults that describe the
operative AUP.

**Two more coverage issues found in other jurisdictions:**

- **Coverage that varies with height.** Hong Kong sets site coverage as a function of building height and site class. Non-domestic parts may cover 100% up to 15 m (v). Podiums in Vancouver and Sydney work the same way. So coverage must be allowed to vary by storey or height band. Today it is one value per site.
- **Coverage that depends on site class.** Hong Kong class A, B and C sites are defined by how many streets the site fronts. NYC allows higher coverage on corner lots (k). The trigger is a morphology output (corner or through site), which is a good reason to keep the `find_*()` family central.

### A2. How the other families combine

The same question comes up across the whole rulebook. One general rule gets
it right: **for each quantity, every applicable rule produces a limit, and
each rule declares how its limit combines with the others.** Seven ways are
enough for every case found:

| Operator | Meaning | Where it is correct |
|---|---|---|
| `cap` (min) | Most restrictive wins | Default for limits: zone height vs height overlays, FAR vs envelope, coverage vs landscaping, density vs volumetric (hybrid), Japan FAR = min(zoned FAR, road width × factor) |
| `envelope` (per-segment max) | All distance rules apply at once, so the largest setback on each boundary at each height wins | Yards, planes, upper-level setbacks, 0.4H rules. This is the same as `cap`, applied geometrically |
| `replace` | A higher-precedence rule replaces the lower one, even if it is more permissive | Precincts, height_override, site-specific controls |
| `floor` (max) | An entitlement that cannot be taken away; the most permissive wins | State-imposed as-of-right minimums: NZ MDRS 3 dwellings, California SB 9 (two units of 800 sq ft; side and rear setbacks no more than 4 ft) (v), ADUs |
| `add` | Bonuses stack | FAR bonuses (plazas, affordable housing), transferred development rights, bonus storeys, ADUs counted on top of the main dwellings; usually with a cap on total bonus |
| `multiply` | Percentage adjustments | Density bonus percentages (California State Density Bonus Law), slope reductions, efficiency factors |
| `composite` | Mixed uses share one limit by fractions | Hong Kong's composite rule: PR_domestic / max_d + PR_non-domestic / max_nd ≤ 1 (k); NYC separate residential and commercial FAR with a combined maximum (k) |

Plus two that are not operators:

- **Variants (either/or).** Alternative routes to compliance, such as MHS's alternative HIRB, form-based building types, or NYC's tower-on-base vs standard tower. Exactly one applies. **Recommendation: the site's enabled capacity is the maximum over its permitted variants**, because the owner chooses the route. Each variant's result is kept so you can report the others. This replaces "choose the reporting rule later" with a default that is easy to defend.
- **Exemptions.** These remove part of a rule. Examples: a plane not applied within 20 m of the frontage; exclusions from GFA; walls on the boundary allowed up to a length (Melbourne B18 (k)).

Implementation: every rule family has a default operator, and an overlay,
area or bonus can declare its own (`combine: cap | replace | floor | add |
multiply`). The old overlay types become shorthands: `height_cap` =
height with `cap`; `height_override` = height with `replace`. The order of
evaluation is fixed and documented: base zone → areas (`replace`) → overlays
(`cap`) → bonuses (`add` / `multiply`) → entitlements (`floor`). `explain_site()`
prints that chain, so you can see why a site got its number.

**Bonuses are conditional**, for example on providing affordable housing.
They are reported in a separate column (`*_with_bonus`) and never folded into
the base "plan-enabled" figure unless the run asks for it.

---

## Part B. Rules not yet handled, by mechanism

Grouped by what the engine would need, not by country. "New" means no
capacityengine equivalent. "Extend" means an existing rule needs a new
parameter.

### B1. Envelope geometry

| Rule | Examples | Engine need |
|---|---|---|
| Setbacks that grow with height | Germany: Abstandsfläche 0.4H, at least 3 m; 0.2H in commercial areas; 0.5H in Lower Saxony's draft (v). Melbourne ResCode B17 side/rear profile (k) | **New primitive: the setback profile** (B5) |
| Street-width planes and heights | Japan: road slant line 1.25:1 (v), measured from the far side of the road (k); FAR = front road width × 0.4 residential / 0.6 commercial (0.6 v, 0.4 k). French "prospect" rules (k). Toronto: height ≤ right-of-way width; the old 45° plane from 80% of ROW is dropped in the 2024 guidelines (v). NYC narrow vs wide street planes | **New input: road width** (`find_road_width()`); a plane origin at the far side of the road or the road centreline |
| Street-facing sky exposure planes above a base height | NYC: R6/R7 initial setback 15 ft, plane from 60 ft, slopes 3.7:1 (narrow street) and 7.6:1 (wide street) (v, column headings to recheck); towers may break the plane in R9/R10 (v) | Extend planes: start height = base height on road boundaries; a variant where towers may break the plane if tower coverage is limited |
| Podium and tower | Vancouver, Toronto, Sydney: podium, step back, slender tower; floorplate caps (Toronto ~750 m² (k)); tower separation (Toronto 25 m (k)) | Coverage by height (A1); upper-level setbacks exist; separation needs B4 |
| Shadow and sunlight | Japan nichiei: hours of winter-solstice shadow on a plane 1.5 m or 4 m up, in bands 5–10 m and >10 m from the boundary, e.g. 3 h / 2 h (v). Wellington CCZ-S6 sunlight to public space. Toronto sidewalk sun. Boulder solar fence (k). Sydney ADG solar access to neighbours (v) | **New, optional module**: sun position by latitude + shadow test + cutting the envelope down until it complies. Heavy; proposed for v2, with v1 holding the rule and flagging it |
| Japan "sky factor" alternative (k) | Performance alternative to slant lines | Flag only (performance-based) |
| How height is measured | Average finished grade, rolling height, RL datum, road level (Japan (k)); exceptions for parapets and plant | Extend `height_limit(datum = ...)` |
| Occupiable roof storeys | Germany's full-storey (Vollgeschoss) rule and partly occupiable attics (k); mansard rules | Extend roof allowance: an occupiable share instead of always zero |
| Minimum floor levels | Flood freeboard raises the ground floor, so fewer storeys fit under a fixed height | New `min_floor_level` (RL or above ground) from a hazard layer |

### B2. Intensity, density and typology

| Rule | Examples | Engine need |
|---|---|---|
| What counts as GFA | Basements, parking, balconies, plant, wall thickness (Hong Kong GFA concessions (v), Vancouver exclusions (k)) | New `gfa_definition`: built floor area → counted floor area, so a FAR limit binds on the right number |
| FAR by use, plus a composite limit | NYC residential vs commercial FAR; Hong Kong domestic vs non-domestic | Operator `composite` (A2) |
| Plot ratio by height and site class | Hong Kong First Schedule (v, structure only) | Ratio bands keyed on height and on corner/through status |
| Units per lot by typology ("missing middle") | Oregon HB 2001, Minneapolis 3 units, SB 9 up to 4 units (v), NZ MDRS | `max_dwellings_per_site` exists; add per-typology minimum lot area / width |
| Form-based codes | Building types allowed per zone; build-to lines; maximum building width | Each permitted building type is a variant; result = max over variants |
| Density measures | Units/acre; habitable rooms/ha (London) (k); bedrooms/acre | Extend density: habitable-room and bedroom units; conversion via a unit mix |
| Unit mix and minimum unit size | UK Nationally Described Space Standard (k); ADG minimum sizes; family-unit shares | Conversion from floor area to dwellings via a mix (sizes by bedroom × shares), not one size |
| Parking minimums | Common in the US and Australia; removed in NZ (NPS-UD) | New `parking_requirement(per_dwelling, per_m2, provision = surface/structured)`; surface parking goes into the ground budget (A1) |
| Open space per dwelling | NYC open space ratio (k); Melbourne private open space (k); Auckland outdoor living | Ground budget `full` mode |
| Slope rules | US hillside codes: density reduction by slope band (e.g. 10% at 16–20% slope, up to 40% at 26–30%); minimum land per dwelling by slope; Cupertino floor area −1.5% per % of slope over 10% (v) | New slope trigger (needs terrain, in v1) + `multiply` or banded density |
| Lot dimensions | Minimum frontage or width for a typology or tower; extra height only on amalgamated sites ≥ X m² | Extend conditions (B6); amalgamation scenarios (v2 helper `amalgamate_sites()`) |
| Rear yard as share of lot depth | San Francisco-style rear yards (k); NYC rear-yard equivalents on through lots (k) | Setback as a formula of site depth (B5) |
| Distance-to-transit bands | California SB 79 (2025) heights by distance to stations (k); NZ walkable catchments; NSW Low and Mid-Rise Housing reforms (k) | **New trigger**: distance bands from a point or line layer |
| Inclusionary zoning and density bonuses | California SDBL (k), NYC MIH (k) | `add` / `multiply` bonuses, reported separately |
| Lot splits | SB 9: minimum new lot 1,200 sq ft, at most a 60/40 split (v) | Extend the density path: potential new lots |
| Accessory dwellings | California ADU + JADU (k) | `floor` / `add` per lot |

### B3. Exclusions and buffers

| Rule | Examples | Engine need |
|---|---|---|
| Tree protection zones | Australian standard AS 4970: radius ~12 × trunk diameter (k); Wellington notable trees | `exclusion` buffered around points, with a radius from an attribute; the LiDAR tree layer already exists |
| Canopy and deep soil | Sydney ADG deep soil 7% under 650 m², 10% for 650–1,500 m², 15% above (v); PC120 canopy | Ground budget + ban on basements under deep soil |
| Bushfire / wildfire | Australian asset protection zones and BAL ratings (k); California WUI (k) | Exclusion buffer from a hazard edge |
| Utility and transport corridors | Transmission lines, pipelines, rail (already listed), road-widening lines | Exclusion by buffer; road widening reduces site area before ratios apply |
| Heritage retention | Facade or building retention | Exclude the retained footprint, or cap the site at what already exists |

### B4. Building separation and form within a site

| Rule | Examples | Engine need |
|---|---|---|
| Separation by height | Sydney ADG 6 / 9 / 12 m by height band (k, the search did not return the table); Christchurch 10 m above 12 m | Item 372 parameters, generalised to separation bands by height |
| Maximum building depth | ADG 12–18 m (k) | New: limits floorplate depth. Model as a strip-packing rule: floorplate ≤ depth limit × usable length |
| Maximum building length | Christchurch 30 m; Wellington HRZ; Melbourne walls on boundaries | Exists (item 372); extend to per-boundary wall length |
| Outlook and privacy distances | UK 21 m back-to-back (k); Auckland outlook spaces | Flag in v1; possible v2 as a buffer from habitable façades |

### B5. A primitive that covers B1: the setback profile

Yards, planes, upper-level setbacks, 0.4H, ResCode B17, Japan's road slant
line and NYC's sky exposure plane are all one thing: **the required distance
from an origin line as a function of height**, d(h). Each one is:

- a piecewise-linear profile (breakpoints of height and setback, with slopes);
- an origin (the boundary, the far side of the road, the road centreline, or a parallel offset);
- a datum (ground at the boundary, site mean, road level, an RL);
- conditions (B6).

The engine already reduces everything to the "required setback per segment
at each storey, take the max", so it handles this with no change. What changes
is the rulebook: the user-facing constructors (`setback()`, `plane()`,
`upper_level_setback()`, `height_proportional_setback()`, `road_slant()`,
`sky_exposure_plane()`) all compile to profiles. A new jurisdiction with an
odd rule can enter the profile directly, with no package code.

### B6. Values as formulas, and new triggers

Many foreign rules are formulas, not numbers: max(3, 0.4H); road width × 0.4;
25% of lot depth; −1.5% per % of slope over 10. Proposal: values may be
**restricted expressions**, parsed and evaluated against a fixed list of
variables and functions (no arbitrary R):

- Variables: `H` (height of the storey under test), `storey`, `site_area`, `site_depth`, `site_width`, `frontage`, `road_width`, `slope`, `distance_to(<layer>)`, `n_frontages`, `is_corner`.
- Functions: `min`, `max`, `clamp`, `step`, `interp`.

They work the same in YAML and XLSX (as a text cell), and are checked at
validation. New triggers: road width, slope, distance band to a layer,
corner/through status, site dimensions, and number of road frontages.

### B7. Process and legal layers

- **Activity status and as-of-right limits:** keep the project's test (the highest limit that is still permitted, controlled or restricted discretionary). US special permits and variances are the same idea.
- **National and state overrides** (NZ MDRS, California SB 9 / ADU / SB 79, Oregon HB 2001, UK permitted development, NSW reforms): an overlay layer or a rulebook-wide block with `combine: floor`, so a local plan cannot take them below the minimum.
- **Performance standards** that cannot be measured from parcels and rules (cross-ventilation, daylight factor, design review): always go to the unmodelled register with a direction of effect.

---

## Part C. Recommendations for v1

1. **Keep "most restrictive" as the default for coverage and landscaping**, and add the ground budget with `with_access` and `full` modes, plus the "no slack" flag. Default output stays the same as capacityengine (required for the stage 4 reproducibility check).
2. **Make the seven combination operators** and the fixed evaluation order part of the rulebook schema from stage 1. They are cheap now and expensive to add later.
3. **The setback profile and restricted formula values** go in stage 1 too. Together they cover most of the foreign envelope rules with no new engine code.
4. **Variants: the default site result is the maximum over permitted variants**, with each variant kept.
5. **Road width, slope, distance-band and corner/through triggers** in stage 2 (morphology).
6. **In v1:** GFA definition, unit mix conversion, parking (surface into the ground budget), coverage by height, bonuses reported separately, tree and other buffer exclusions, minimum floor level.
7. **v2:** shadow / sunlight module, building depth and separation packing, outlook, amalgamation scenarios. Each held as a rule in v1 and flagged.

---

## Sources

- Japan: [Building Standards Act (English)](https://www.japaneselawtranslation.go.jp/en/laws/view/4024/en); [Yokohama, slant line restrictions](https://en.city.yokohama.lg.jp/business/bunyabetsu/kenchiku/tetsuduki/kuiki/chousei.html); [Yokohama, FAR by road width](https://en.city.yokohama.lg.jp/business/bunyabetsu/kenchiku/tetsuduki/kuiki/52-2-3.html); [Yokohama, shadow regulation](https://en.city.yokohama.lg.jp/business/bunyabetsu/kenchiku/tetsuduki/jorei/nitiei.html); [Kobe, shadow regulation](https://www.city.kobe.lg.jp/a81042/business/todokede/jutakutoshikyoku/building/procedure/hikage.html)
- Victoria: [PPN84 minimum garden area](https://www.planning.vic.gov.au/guides-and-resources/guides/planning-practice-notes/applying-the-minimum-garden-area-requirement) (25% / 30% / 35% for lots 400–500 / 500–650 / >650 m² (v))
- NSW: [Apartment Design Guide Part 3](https://www.planning.nsw.gov.au/sites/default/files/2023-03/apartment-design-guide-part-3-siting-the-development.pdf); [Part 2](https://www.planning.nsw.gov.au/sites/default/files/2023-03/apartment-design-guide-part-2-developing-the-controls.pdf)
- NYC: [Zoning Resolution 23-736](https://zoningresolution.planning.nyc.gov/node/18077); [front setbacks](https://zr.planning.nyc.gov/node/17672)
- Germany: [BayBO Art. 6 Abstandsflächen](https://www.gesetze-bayern.de/Content/Document/BayBO-6); [München, Abstandsflächen overview](https://stadt.muenchen.de/dam/jcr:f059dc5e-7847-49a6-9212-fac2e0d9c4df/%C3%9Cbersicht_Abstandsfl%C3%A4chen_2021.pdf); [NBauO draft synopsis](https://www.mw.niedersachsen.de/download/202157/Synopse_NBauO_GE-NBauO_Auszug.pdf)
- Toronto: [Mid-rise building design guidelines](https://www.toronto.ca/city-government/planning-development/official-plan-guidelines/design-guidelines/mid-rise-building-design-guidelines/); [2010 performance standards](https://www.toronto.ca/wp-content/uploads/2017/08/960c-Performance-Standards-for-Mid-Rise-Buildings.pdf); [2024 staff report](https://www.toronto.ca/legdocs/mmis/2024/ph/bgrd/backgroundfile-250941.pdf)
- Hong Kong: [L.N. 110 of 2005, B(P)R amendment](https://www.legco.gov.hk/yr04-05/english/subleg/negative/ln110-05-e.pdf); [DEVB joint practice note 7](https://www.devb.gov.hk/filemanager/en/content_1309/jpn07_e.pdf)
- California: [HCD SB 9 fact sheet](https://www.hcd.ca.gov/sites/default/files/docs/planning-and-community/sb-9-fact-sheet.pdf); [HCD lot splits and duplexes](https://www.hcd.ca.gov/sites/default/files/docs/planning-and-community/lot-splits-and-duplexes-sb-9.pdf)
- Hillside slope rules: [Concord](https://www.codepublishing.com/CA/Concord/html/Concord18/Concord18300.html); [Cupertino](https://www.cupertino.gov/Your-City/Departments/Community-Development/Planning/Residential-Planning/Residential-Hillside-Development); [Pima County](https://codelibrary.amlegal.com/codes/pimacounty/latest/pimacounty_az/0-0-0-20911); [Milpitas](https://www.zoneomics.com/code/milpitas-CA/chapter_19)
