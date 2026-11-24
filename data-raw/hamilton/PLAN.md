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

## H3 Overlays, PC14 and the city-wide run

Historic heritage (built heritage, heritage areas), significant natural
areas, special character, PC14 flood hazard (proposed); a LINZ parcel
download for the whole city; a city-wide run with check_capacity(); the
vignette and docs updated.
