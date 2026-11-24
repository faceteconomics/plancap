# Enter Hamilton's residential and neighbourhood centre rules through the
# Excel template, as a user would: write a blank template, fill its sheets
# row by row from the plan text (data-raw/hamilton/rules_notes.md), and read
# it back as a rulebook.
#
# Run from the package root:  Rscript data-raw/hamilton/fill_template.R
# Writes inst/extdata/hamilton_rulebook.xlsx (the filled template) and
# inst/rulebooks/hamilton.yaml (the same rulebook as YAML).
#
# Source: Hamilton City Operative District Plan, ePlan revision 13 November
# 2026 (Plan Change 12 operative 20 December 2024). Every value cites its
# rule.

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
xlsx <- "inst/extdata/hamilton_rulebook.xlsx"
rulebook_template(xlsx)
wb <- openxlsx2::wb_load(xlsx)
put <- function(sheet, df) {
  cols <- names(openxlsx2::read_xlsx(xlsx, sheet = sheet))
  miss <- setdiff(names(df), cols)
  if (length(miss)) stop("Sheet ", sheet, " has no column ", paste(miss, collapse = ", "))
  full <- as.data.frame(matrix(NA, nrow(df), length(cols), dimnames = list(NULL, cols)))
  for (cc in names(df)) full[[cc]] <- df[[cc]]
  wb <<- openxlsx2::wb_add_data(wb, sheet = sheet, x = full, start_row = 2, col_names = FALSE, na.strings = "")
}
src <- function(rule) paste0("HCC ODP ", rule)

# ---- plan ---------------------------------------------------------------------
plan <- read.csv(text = '
section,key,value
plan,name,"Hamilton City Operative District Plan"
plan,id,hamilton-odp-2026
plan,jurisdiction,Hamilton
plan,country,NZ
plan,effective_date,2026-11-13
plan,units,m
plan,source,"Hamilton City Operative District Plan, ePlan revision 13 November 2026 (Plan Change 12 operative 20 December 2024)"
plan,notes,"Entered through the Excel template from the ePlan; built out in stages (data-raw/hamilton/PLAN.md). Plan Change 14 (Flooding) rules are proposed, flagged where used."
plan,variant_choice,max
defaults,storey_height,3
defaults,min_floorplate,30
defaults,level_reference,ceiling
defaults,terrain,flat
defaults,site_shape_factor,TRUE
defaults,large_site_method,envelope
defaults,large_site_threshold,10000
defaults,large_site_deduction,0.25
conversion,dwelling_size,100
conversion,efficiency,0.85
conversion,min_one_dwelling,TRUE
conversion,source,"Assumption for the walkthrough: 100 m2 gross per dwelling, 85% of floor area in dwellings"
morphology,reserve_families,OPEN_SPACE
morphology,road_class_field,FIRST_Road_Classification
', stringsAsFactors = FALSE, strip.white = TRUE)
wb <- openxlsx2::wb_clean_sheet(wb, sheet = "plan", dims = "A2:C200")
wb <- openxlsx2::wb_add_data(wb, sheet = "plan", x = plan, start_row = 2, col_names = FALSE)

# ---- zones --------------------------------------------------------------------------
none <- function(key, label, codes) data.frame(zone = key, codes = codes, label = label, method = "none",
                                               source = src("zone"), stringsAsFactors = FALSE)
zones <- rbind(
  data.frame(zone = "GRZ", codes = "General Residential", label = "General Residential Zone", method = "volumetric",
             height = 10, occupiable = 10, roof_allowance = 1, storeys = NA, height_source = src("4.2.5.4"),
             coverage_max = 0.45, coverage_max_source = src("4.2.5.2"),
             landscaping_min = 0.2, landscaping_min_source = src("4.2.5.3 b"),
             impervious_max = 0.7, impervious_max_source = src("4.2.5.3 a"),
             site_shape_width = NA, site_shape_depth = NA,
             minor_dwellings_per_site = 1, density_source = src("4.2.3.1, 4.2.6.1: ancillary residential unit, one per site"),
             residential = TRUE, business = FALSE, use_source = src("4.2.3.1"),
             source = "HCC ODP 4.2 General Residential Zone", stringsAsFactors = FALSE),
  data.frame(zone = "MRZ", codes = "Medium Density Residential", label = "Medium Density Residential Zone",
             method = "volumetric", height = 18, occupiable = 18, roof_allowance = 1, storeys = 5,
             height_source = src("4.3.4.4 a"),
             coverage_max = 0.5, coverage_max_source = src("4.3.4.2"),
             landscaping_min = 0.2, landscaping_min_source = src("4.3.4.3"),
             impervious_max = 0.7, impervious_max_source = src("4.3.4.3"),
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = NA, density_source = NA,
             residential = TRUE, business = FALSE, use_source = src("4.3.3.1"),
             source = "HCC ODP 4.3 Medium Density Residential Zone", stringsAsFactors = FALSE),
  data.frame(zone = "HDZ", codes = "High Density Residential", label = "High Density Residential Zone",
             method = "volumetric", height = 26, occupiable = 26, roof_allowance = 1, storeys = NA,
             height_source = src("4.4.5.4"),
             coverage_max = 0.6, coverage_max_source = src("4.4.5.2"),
             landscaping_min = 0.1, landscaping_min_source = src("4.4.5.3"),
             impervious_max = 0.8, impervious_max_source = src("4.4.5.3"),
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = NA, density_source = NA,
             residential = TRUE, business = FALSE, use_source = src("4.4.3.1"),
             source = "HCC ODP 4.4 High Density Residential Zone", stringsAsFactors = FALSE),
  data.frame(zone = "LLRZ", codes = "Large Lot Residential", label = "Large Lot Residential Zone",
             method = "hybrid", height = 10, occupiable = 10, roof_allowance = NA, storeys = NA,
             height_source = src("4.5.4.4"),
             coverage_max = 0.2, coverage_max_source = src("4.5.4.2"),
             landscaping_min = 0.7, landscaping_min_source = src("4.5.4.3 b: permeable surface 70%"),
             impervious_max = NA, impervious_max_source = NA,
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = 1,
             density_source = src("4.5.4.1: 2,500 m2 per residential unit (SH26 Ruakura Structure Plan area); 4.5.3.1 ancillary unit P"),
             residential = TRUE, business = FALSE, use_source = src("4.5.3.1"),
             source = "HCC ODP 4.5 Large Lot Residential Zone", stringsAsFactors = FALSE),
  data.frame(zone = "PMRZ", codes = "Peacocke Medium Density Residential",
             label = "Medium Density Residential Zone, Peacocke Precinct", method = "volumetric",
             height = 12, occupiable = 12, roof_allowance = NA, storeys = 3,
             height_source = src("4A MRZ-PREC1-PSP R37: 12 m, 3 storeys"),
             coverage_max = 0.6, coverage_max_source = src("4A R34: 60% for terraced houses and apartments (50% single and duplex)"),
             landscaping_min = 0.2, landscaping_min_source = src("4A R35, R36: permeable and landscaped 20%"),
             impervious_max = NA, impervious_max_source = NA,
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = NA, density_source = NA,
             residential = TRUE, business = FALSE, use_source = src("4A R1-R4"),
             source = "HCC ODP Chapter 4A Medium Density Residential Zone, Peacocke Precinct", stringsAsFactors = FALSE),
  data.frame(zone = "B6G", codes = "Business 6 (General Residential)",
             label = "Business 6 Zone, adjacent to the General Residential Zone", method = "volumetric",
             height = 11, occupiable = 11, roof_allowance = 1, storeys = NA, height_source = src("6.4.1"),
             coverage_max = NA, coverage_max_source = NA, landscaping_min = NA, landscaping_min_source = NA,
             impervious_max = NA, impervious_max_source = NA,
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = NA, density_source = NA,
             residential = TRUE, business = TRUE, use_source = src("6.3, 6.4.7: no residential activity at ground floor"),
             source = "HCC ODP 6 Business 6 Zone (neighbourhood centre)", stringsAsFactors = FALSE),
  data.frame(zone = "B6M", codes = "Business 6 (Medium Density Residential)",
             label = "Business 6 Zone, adjacent to the Medium Density Residential Zone", method = "volumetric",
             height = 18, occupiable = 18, roof_allowance = NA, storeys = NA, height_source = src("6.4.1"),
             coverage_max = NA, coverage_max_source = NA, landscaping_min = NA, landscaping_min_source = NA,
             impervious_max = NA, impervious_max_source = NA,
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = NA, density_source = NA,
             residential = TRUE, business = TRUE, use_source = src("6.3, 6.4.7: no residential activity at ground floor"),
             source = "HCC ODP 6 Business 6 Zone (neighbourhood centre)", stringsAsFactors = FALSE),
  data.frame(zone = "B2", codes = "Business 2", label = "Business 2 Zone (Events Facilities Fringe)",
             method = "volumetric", height = 16, occupiable = 16, roof_allowance = NA, storeys = NA,
             height_source = src("6.4.1"),
             coverage_max = NA, coverage_max_source = NA, landscaping_min = NA, landscaping_min_source = NA,
             impervious_max = NA, impervious_max_source = NA,
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = NA, density_source = NA,
             residential = FALSE, business = TRUE, use_source = src("6.3: residential units not provided for"),
             source = "HCC ODP 6 Business 2 Zone", stringsAsFactors = FALSE)
)
zones$far_max <- c(NA, NA, NA, NA, NA, 2, 3, 2)
zones$far_max_source <- c(NA, NA, NA, NA, NA, src("6.4.4"), src("6.4.4"), src("6.4.4"))
zones$site_area_per_dwelling <- c(NA, NA, NA, 2500, NA, NA, NA, NA)
others <- rbind(none("CFZ", "Community Facilities Zone", "Community Facilities"),
                none("MFZ", "Major Facilities Zone", "Major Facilities"),
                none("OSZ", "Open Space Zones", "Open Space"),
                none("INZ", "Industrial Zone", "Industrial"),
                none("TCZ", "Transport Corridor Zone", "Transport Corridor"))
for (cc in setdiff(names(zones), names(others))) others[[cc]] <- NA
zones <- rbind(zones, others[, names(zones)])
zones$site_shape_width <- NULL
zones$site_shape_depth <- NULL
put("zones", zones)

ART <- "state_highway, major_arterial_road, minor_arterial_road"
sb <- function(target, kind, boundaries, ..., source) {
  data.frame(target = target, kind = kind, boundaries = boundaries, ..., source = source, stringsAsFactors = FALSE)
}

# ---- overlays: infrastructure capacity, gully hazard ----------------------------------------
ov <- data.frame(
  id = c("infrastructure_grz", "infrastructure_mrz", "gully_hazard"),
  label = c("Three Waters Infrastructure Capacity Overlay (General Residential)",
            "Three Waters Infrastructure Capacity Overlay (Medium Density Residential)",
            "Waikato Riverbank and Gully Hazard Area"),
  type = c("parameters", "parameters", "exclusion"),
  layer = c("infrastructure_capacity", "infrastructure_capacity", "gully_hazard"),
  combine = c("replace", "replace", NA), removes = c(NA, NA, "all"), buffer = c(NA, NA, "6"),
  applies_to_zones = c("GRZ", "MRZ", NA),
  source = c(src("4.2.5.1: density inside the Three Waters Infrastructure Capacity Overlay"),
             src("4.3.4.1: density inside the Three Waters Infrastructure Capacity Overlay"),
             src("22.3, 22.2.1l: new buildings D and vulnerable use to avoid the area; 4.2.5.6, 4.3.4.6, 4.4.5.6, 4A R38, 6.4.3: 6 m setback")),
  stringsAsFactors = FALSE)
put("overlays", ov)

# ---- areas: residential precincts --------------------------------------------------------------
ar <- data.frame(id = "rotokauri_north", label = "Rotokauri North Residential Precinct", layer = "precincts",
                 filter = "Name=Rotokauri North Residential Precinct", applies_to_zones = "MRZ", combine = "replace",
                 source = src("4.3.4.4 b, 4.3.4.6 m-o: Rotokauri North Residential Precinct"), stringsAsFactors = FALSE)
put("areas", ar)
ch <- data.frame(target = c("overlay:infrastructure_grz", "overlay:infrastructure_mrz", "area:rotokauri_north"),
                 method = c("hybrid", "hybrid", NA),
                 site_area_per_dwelling = c(200, 150, NA),
                 density_source = c(src("4.2.5.1: average net site area 200 m2 per unit"), src("4.3.4.1: average net site area 150 m2 per unit"), NA),
                 height = c(NA, NA, 11), height_source = c(NA, NA, src("4.3.4.4 b: Rotokauri North Residential Precinct 11 m")),
                 stringsAsFactors = FALSE)
put("changes", ch)
rows2 <- list(sb("area:rotokauri_north", "upper_level", "rear", distance = 8, above_height = 5,
                 source = src("4.3.4.6 m: rear yard 8 m for a building over 5 m (four or more units)")))

# ---- setbacks ---------------------------------------------------------------------------
rows <- list(
  # General Residential, 4.2.5.5 and 4.2.5.6.
  sb("GRZ", "yard", "road", distance = 1.5, source = src("4.2.5.6 a: local and collector transport corridors")),
  sb("GRZ", "yard", "side", distance = 1.5, source = src("4.2.5.6 b")),
  sb("GRZ", "yard", "rear", distance = 1.5, source = src("4.2.5.6 d")),
  sb("GRZ", "plane", "side, rear", angle_deg = 45, start_height = 4, source = src("4.2.5.5: 45 degrees from 4 m, all boundaries except a road")),
  # Medium Density, standard (a): single and duplex units.
  sb("MRZ", "yard", "road", distance = 1.5, source = src("4.3.4.6 a ii")),
  sb("MRZ", "yard", "side", distance = 1, source = src("4.3.4.6 b")),
  sb("MRZ", "yard", "rear", distance = 1, source = src("4.3.4.6 d")),
  sb("MRZ", "plane", "side, rear", angle_deg = 60, start_height = 4, not_adjacent_zones = "GRZ", variant = "single_duplex",
     source = src("4.3.4.5 a: single and duplex units, 60 degrees from 4 m")),
  sb("MRZ", "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ", variant = "single_duplex",
     source = src("4.3.4.5 a: 45 degrees from 4 m along a General Residential boundary")),
  # Medium Density, standard (b): three or more attached units.
  sb("MRZ", "upper_level", "side", distance = 4, above_height = 11, within_frontage = 20, not_adjacent_zones = "GRZ",
     variant = "attached", source = src("4.3.4.5 b: within 20 m of the road, parts over 11 m set back 4 m from side boundaries")),
  sb("MRZ", "plane", "side, rear", angle_deg = 60, start_height = 6, beyond_frontage = 20, not_adjacent_zones = "GRZ",
     variant = "attached", source = src("4.3.4.5 b, Figure 4.3.4.5 b: beyond 20 m of the road, 60 degrees from 6 m")),
  sb("MRZ", "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ", variant = "attached",
     source = src("4.3.4.5 b: boundaries adjoining other zones take 4.3.4.5 a")),
  # Arterial transport corridors, 5 m (road boundaries tagged by road class).
  sb("GRZ", "yard", ART, distance = 5, source = src("4.2.5.6 a: arterial transport corridors")),
  sb("MRZ", "yard", ART, distance = 5, source = src("4.3.4.6 a iii: arterial transport corridors")),
  sb("HDZ", "yard", ART, distance = 5, source = src("4.4.5.6: arterial transport corridors")),
  sb("B6G", "yard", ART, distance = 5, source = src("6.4.3: 5 m when fronting an arterial transport corridor")),
  sb("B6M", "yard", ART, distance = 5, source = src("6.4.3")),
  sb("B2", "yard", ART, distance = 5, source = src("6.4.3")),
  # Large Lot Residential, 4.5.4.5 and 4.5.4.6.
  sb("LLRZ", "yard", "road", distance = 5, source = src("4.5.4.6 a")),
  sb("LLRZ", "yard", "side", distance = 1.5, source = src("4.5.4.6 b")),
  sb("LLRZ", "yard", "rear", distance = 1.5, source = src("4.5.4.6 d")),
  sb("LLRZ", "plane", "side, rear", angle_deg = 45, start_height = 3, angle_by_bearing = "135-225:28",
     source = src("4.5.4.5: 28 degrees between north-west and north-east (Figure 4.5.4.5 b: the line into the site), 45 degrees otherwise, from 3 m")),
  sb("LLRZ", "plane", "road", angle_deg = 45, start_height = 3, source = src("4.5.4.5: 45 degrees from 3 m along a transport corridor")),
  # Peacocke Medium Density, 4A R38 and R39.
  sb("PMRZ", "yard", "road", distance = 1.5, source = src("4A R38")),
  sb("PMRZ", "yard", "side", distance = 1, source = src("4A R38")),
  sb("PMRZ", "yard", "rear", distance = 1, source = src("4A R38")),
  sb("PMRZ", "plane", "side, rear", angle_deg = 60, start_height = 4, source = src("4A R39: 60 degrees from 4 m, not a road boundary")),
  # High Density, 4.4.5.5, 4.4.5.6, 4.4.5.14.
  sb("HDZ", "yard", "road", distance = 1, source = src("4.4.5.6: local and collector transport corridors")),
  sb("HDZ", "yard", "side", distance = 1, source = src("4.4.5.6")),
  sb("HDZ", "yard", "rear", distance = 1, source = src("4.4.5.6")),
  sb("HDZ", "upper_level", "side, rear", distance = 4, above_height = 11, source = src("4.4.5.14: parts over 11 m set back 4 m from side and rear boundaries")),
  sb("HDZ", "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ",
     source = src("4.4.5.5: 45 degrees from 4 m along a General Residential boundary")),
  sb("HDZ", "plane", "side, rear", angle_deg = 60, start_height = 6, adjacent_zones = "MRZ", beyond_frontage = 20,
     source = src("4.4.5.5: along a Medium Density boundary beyond 20 m of the road, 60 degrees from 6 m")),
  sb("HDZ", "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "CFZ, MFZ",
     source = src("4.4.5.5 a: 60 degrees from 4 m along a boundary with any other zone")),
  # Business 6 and Business 2, 6.4.2 and 6.4.3.
  sb("B6G", "yard", "side, rear", distance = 1.5, adjacent_zones = "RESIDENTIAL", source = src("6.4.3: Business 6, 1.5 m where the boundary adjoins a Residential Zone")),
  sb("B6G", "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ", source = src("6.4.2: adjoining General Residential")),
  sb("B6G", "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "MRZ", source = src("6.4.2: adjoining Medium Density Residential")),
  sb("B6M", "yard", "side, rear", distance = 1.5, adjacent_zones = "RESIDENTIAL", source = src("6.4.3")),
  sb("B6M", "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ", source = src("6.4.2")),
  sb("B6M", "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "MRZ", source = src("6.4.2")),
  sb("B2", "yard", "side, rear", distance = 5, adjacent_zones = "RESIDENTIAL", source = src("6.4.3: Business 2, 5 m where the boundary adjoins a Residential Zone")),
  sb("B2", "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ", source = src("6.4.2")),
  sb("B2", "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "MRZ", source = src("6.4.2"))
)
rows <- c(rows, rows2)
cols <- unique(unlist(lapply(rows, names)))
setbacks <- do.call(rbind, lapply(rows, function(r) { for (cc in setdiff(cols, names(r))) r[[cc]] <- NA; r[, cols] }))
put("setbacks", setbacks)

# ---- bands: residential share by storey in Business 6 -----------------------------------------
bands <- data.frame(target = rep(c("B6G", "B6M"), each = 2), rule = "residential_share", by = "storey",
                    upper = rep(c(1, NA), 2), value = rep(c(0, 1), 2),
                    source = rep(c(src("6.4.7 b: no residential activity at ground floor"), NA), 2))
put("bands", bands)

# ---- families --------------------------------------------------------------------------------
fam <- data.frame(family = c("RESIDENTIAL", "BUSINESS", "OPEN_SPACE"),
                  zones = c("GRZ, MRZ, HDZ, LLRZ, PMRZ", "B6G, B6M, B2", "OSZ"))
put("families", fam)

# ---- unmodelled ------------------------------------------------------------------------------
um <- data.frame(
  rule = c("Separation between residential buildings on a site; upper-floor balcony setbacks",
           "Outlook space, outdoor living area, front landscaping, tree canopy, wall articulation",
           "Maximum average net site area (MRZ, HDZ) and minimum residential density (Business 6)",
           "Building coverage of 60% for terraces and apartments with rear-lane parking",
           "Peacocke: 50% coverage for single and duplex units; Increased Height Overlay (16 m); bat habitat setback",
           "Large Lot: 2 ha density in the Percival and Ryburn Road area",
           "Te Rapa Racecourse, Ruakura, Te Awa Lakes and Rototuna North East precinct rules",
           "Rotokauri North: other precinct standards (front yard, site-wide density)"),
  reason = c("A single envelope per site does not place separate buildings or balconies.",
             "Depend on where buildings, windows and planting go, which a blank-slate envelope does not know.",
             "These require a minimum intensity; they do not cap capacity.",
             "Needs a rear lane, which the extract does not identify.",
             "The 60% terrace and apartment coverage is used; the height overlay and bat habitat layers are not held.",
             "The area is not mapped as a layer.",
             "Staging, structure plan and expressway rules that depend on infrastructure delivery or on layers not held.",
             "Only the 11 m height and the 8 m rear yard above 5 m are entered."),
  zones = c("GRZ, MRZ, HDZ", "GRZ, MRZ, HDZ", "MRZ, HDZ, B6G, B6M", "GRZ, MRZ", "PMRZ", "LLRZ",
            "GRZ, MRZ, LLRZ", "MRZ"),
  likely_effect = c("overstates", "overstates", "either", "understates", "either", "overstates", "either", "either"),
  source = c(src("4.2.5.6, 4.3.4.6, 4.4.5.6"), src("4.2.5.3, 4.2.5.9, 4.2.5.10, 4.2.5.13 and equivalents"),
             src("4.3.4.1, 4.4.5.1, 6.4.7"), src("4.2.5.2 b, 4.3.4.2 b"), src("4A R34, R37, R38"),
             src("4.5.4.1"), src("4.2, 4.3 precinct rules"), src("4.3.4.6 m-o")))
put("unmodelled", um)

openxlsx2::wb_save(wb, xlsx, overwrite = TRUE)
rb <- read_rulebook(xlsx)
print(rb)
print(validate_rulebook(rb))
write_rulebook(rb, "inst/rulebooks/hamilton.yaml")
hdr <- c("# Hamilton City Operative District Plan: the walkthrough rulebook.",
         "#",
         "# Entered through the Excel template (inst/extdata/hamilton_rulebook.xlsx) by",
         "# data-raw/hamilton/fill_template.R from the ePlan revision of 13 November 2026.",
         "# Built out in stages (data-raw/hamilton/PLAN.md); PC14 rules are proposed;",
         "# check the plan itself before relying on any value.", "")
writeLines(c(hdr, readLines("inst/rulebooks/hamilton.yaml")), "inst/rulebooks/hamilton.yaml")
