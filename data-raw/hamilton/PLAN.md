# Building out the Hamilton rulebook

Decided 23 Nov 2026 (user): the whole plan, staged; Plan Change 14 (Flooding)
included now as though in force, every PC14 rule flagged as proposed
(`activity_status`/source notes "PC14 (proposed)").

Source of truth: the Excel template, `inst/extdata/hamilton_rulebook.xlsx`,
filled by `data-raw/hamilton/fill_template.R` from the plan text noted in
`rules_notes.md` (rule numbers for every value). Plan: Hamilton City Operative
District Plan ePlan (https://hamilton.isoplan.co.nz/eplan/), revision of
13 Nov 2026; read in the browser (ePlan terms accepted with the user's
approval; re-accept on direct page loads).

## H1 Residential, complete

- 4.5 Large Lot Residential; Chapter 4A Medium Density Residential Zone (MRZ)
  and where it applies; Peacocke (Chapter 3A) residential zones and the
  Peacocke Local Centre.
- Residential precincts (Rototuna North East, Ruakura, Te Awa Lakes,
  Rotokauri North, Te Rapa Racecourse): areas with their rule changes, from
  the PC12 Precincts layer (eplan_pc12_amendments_data/141).
- Three Waters Infrastructure Capacity Overlay (eplan_pc12_amendments_data/130):
  density 200 m2 (GRZ) and 150 m2 (MRZ) per unit inside it.
- Waikato Riverbank and Gully Hazard Area (GEOTECH_AND_HYDRO___DP_Waikato_River_Gully_Hazard_Area):
  6 m setback, and Chapter 22's rules inside it.
- Arterial transport corridor setback (5 m): needs the road hierarchy layer.

Status 25 Nov 2026: H1 entered and run. Extracts claudelands (cache root),
peacocke and ruakura (`fetch.R <name>`, `run.R`); all checks pass. Large Lot,
Peacocke MRZ (4A), infrastructure overlays (hybrid density), gully exclusion
(6 m buffer), Rotokauri North (11 m, 8 m rear above 5 m; not in any extract
yet) and 5 m arterial yards (road classes tagged from RoadHierarchy20260623 via
`morphology$road_class_field`). Unmodelled: Peacocke 16 m overlay and bat
habitat setback (no layer found), the 2 ha Percival/Ryburn density, staging
precincts. prepare.R resolves the council's sliver overlaps (st_difference).
The pre-computed vignette still shows the stage 8 numbers: re-knit in H3.

## H2 Centres and business

Business 1 to 7, Central City (Downtown, City Living, Ferrybank precincts and
height overlays), Rototuna Town Centre, Peacocke centres, Knowledge,
Industrial, Logistics, Ruakura, Te Rapa North (floor area where no dwellings
are provided for).

Status 25 Nov 2026: H2 entered and run. New extracts frankton, thebase, terapa,
university (all seven pass check_capacity). Business 1-7 (B4 coded by
adjacency to Industrial), Peacocke centres (6A, 6B), Central City precincts
(height 32 m: an ASSUMPTION, Chapter 7 has no height limit), Knowledge,
Industrial (+ Amenity Protection Area overlay from the zoning layer), Ruakura
Logistics and Industrial Park, Te Rapa North; Peacocke Increased Height
Overlay (PC12_Features/24, 16 m). Method none: University precinct, Te Rapa
North Deferred, Rototuna Town Centre, Future Urban. Storey height decided by the
user 25 Nov: industrial, logistics, industrial park and Te Rapa North
zones now use a 7 m storey (assumption, user choice): FAR about 1.5-1.7.

## H3 Overlays, PC14 and the city-wide run

Historic heritage (built heritage, heritage areas), significant natural
areas, special character, PC14 flood hazard (proposed); a LINZ parcel
download for the whole city; a city-wide run with check_capacity(); the
vignette and docs updated.

Status 25 Nov 2026: H3 overlays entered (rules_notes.md "H3 Overlays"):
built heritage (parcels holding PC9 Schedule 8A points, excluded), Historic
Heritage Areas (residential zones: 1 dwelling, 8 m, 2 storeys, 35%, 40%
permeable, 28/45 deg plane), Significant Natural Areas (excluded), PC14 High
Flood Hazard Area (Floodviewer hazard factor 4, both models; excluded;
PROPOSED, read from the officer's rebuttal version of 12 Sep 2025, decision
24 Dec 2025 under appeal). The operative flood maps are not used. City-wide
extract: `fetch.R city` (zoning extent; prepare.R drops parcels outside the
zoning); `run.R city` (long; not in the default run).

City run 25 Nov 2026 (141 min, one core): 60,705 land parcels, 61,520 sites
on 9,170 ha; 104.9 million m2 floor area (82.1m residential, 22.8m
business), 469,395 dwellings and 130,277 minor dwellings. All
check_capacity() checks pass; 322 sites have no zone (parcels under the
dropped Transport Corridor polygon), 2,520 are in no-capacity zones. MRZ
16.0m m2 enabled floor area, PMRZ 10.5m. Vignette section 8 reads the saved
run.rds.

Net site area (27 Nov 2026). Hamilton's 1.1 definitions (as amended by PC12)
measure density and floor area ratio on net site area, without entrance
strips, internal vehicle access and private ways. The engine now has
`morphology: density_area` and `far_area` ("gross", the default, as
capacityengine, or "net"); Hamilton's rulebook sets both to "net". City
re-run (160 min): 104.9m m2 floor area, 466,970 dwellings (-2,425 against the
gross basis) and 128,546 minor dwellings; all check_capacity() checks pass.

Verification (27 Nov 2026): `verify.R [extract|city]` checks saved runs
against rules rebuilt independently from the zone and overlay layers (15
checks: storeys, height, coverage, landscaping, FAR, floor within footprint
times storeys, dwellings, site area per dwelling, minor dwellings, uses,
method none, wholly excluded sites, removed area against the exclusion
layers). Every check passes on the six extracts and the city (55,975 sites
checked; precinct sites left out of the bounds). `compare.R` runs five
scenarios on Claudelands (same, no PC14, no heritage areas, GRZ to MRZ,
combined): check_comparison 53/53, Shapley consistent, incremental equals
full. Open engine issues found: toggling an exclusion or changing zoning
rebuilds every site; sites losing a PC14 exclusion are labelled
neighbour_effect; 19 changed sites have no reason code.
