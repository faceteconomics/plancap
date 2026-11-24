# Enter Hamilton's district plan rules through the
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
zones$storey_height <- NA

# H2: centres, business and industrial zones. Floor area where dwellings are
# not provided for; residential above ground floor where they are (P).
bz <- function(zone, codes, label, height, height_source, residential, use_source, source,
               far = NA, far_source = NA, coverage = NA, coverage_source = NA,
               landscaping = NA, landscaping_source = NA, storeys = NA, storey_height = NA) {
  data.frame(zone = zone, codes = codes, label = label, method = "volumetric",
             height = height, occupiable = height, roof_allowance = NA, storeys = storeys,
             height_source = height_source, storey_height = storey_height,
             coverage_max = coverage, coverage_max_source = coverage_source,
             landscaping_min = landscaping, landscaping_min_source = landscaping_source,
             impervious_max = NA, impervious_max_source = NA,
             site_shape_width = NA, site_shape_depth = NA, minor_dwellings_per_site = NA, density_source = NA,
             residential = residential, business = TRUE, use_source = use_source, source = source,
             far_max = far, far_max_source = far_source, site_area_per_dwelling = NA, stringsAsFactors = FALSE)
}
B6 <- "HCC ODP 6 Business 1 to 7 Zones"
# Industrial buildings are tall single storeys, not 3 m floors: a 7 m storey
# (an assumption, user's choice 25 Nov 2026) gives two storeys under 20 m and
# one under the Amenity Protection Area's 10 m.
IND_STOREY <- 7
res_above <- function(z) src(paste0("6.3: residential units above ground floor P in ", z, "; at ground floor NC"))
zones <- rbind(zones,
  bz("B1", "Business 1", "Business 1 Zone (Commercial Fringe)", 16, src("6.4.1"), TRUE, res_above("Business 1"), B6,
     far = 2, far_source = src("6.4.4")),
  bz("B3", "Business 3", "Business 3 Zone (Sub-Regional Centre)", 20, src("6.4.1"), TRUE, res_above("Business 3"), B6,
     far = 2, far_source = src("6.4.4")),
  bz("B4", "Business 4", "Business 4 Zone (Large Format Retail)", 16, src("6.4.1"), FALSE,
     src("6.3: residential units NC"), B6, far = 2, far_source = src("6.4.4")),
  bz("B4I", "Business 4 (Industrial)", "Business 4 Zone, adjoining the Industrial Zone", 20,
     src("6.4.1: 20 m where adjoining the Industrial Zone"), FALSE, src("6.3: residential units NC"), B6,
     far = 2, far_source = src("6.4.4")),
  bz("B5", "Business 5", "Business 5 Zone (Suburban Centre)", 26, src("6.4.1"), TRUE, res_above("Business 5"), B6,
     far = 4, far_source = src("6.4.4")),
  bz("B7", "Business 7", "Business 7 Zone (Frankton Commercial Fringe)", 16, src("6.4.1"), FALSE,
     src("6.3: residential units D (P above ground floor in the Frankton Living Overlay, not mapped)"), B6,
     far = 2, far_source = src("6.4.4")),
  bz("PNCZ", "Peacocke Neighbourhood Centre", "Neighbourhood Centre Zone, Peacocke Precinct", 16,
     src("6A NCZ-PREC1-PSP R46"), TRUE, src("6A R22: apartments P, not at ground floor; R26-R28 dwellings NC or D"),
     "HCC ODP 6A Neighbourhood Centre Zone, Peacocke Precinct"),
  bz("PLCZ", "Peacocke Local Centre", "Local Centre Zone, Peacocke Precinct", 24,
     src("6B LCZ-PREC1-PSP R40: 24 m (16 m within 30 m of a Residential or Open Space Zone)"), TRUE,
     src("6B R21: apartments P, not at ground floor; R36 single dwellings NC"),
     "HCC ODP 6B Local Centre Zone, Peacocke Precinct"),
  bz("CC1", "Central City Downtown", "Central City Zone, Precinct 1 (Downtown)", 32,
     "Assumption: Chapter 7 sets no maximum height; 32 m is the height above which new buildings (RD*) take added design matters (7.3)",
     TRUE, src("7.3: residential units above ground floor P; apartments at ground floor P outside active frontages"),
     "HCC ODP 7 Central City Zone", coverage = 1, coverage_source = src("7.4.1")),
  bz("CC2", "Central City City Living", "Central City Zone, Precinct 2 (City Living)", 32,
     "Assumption: no maximum height in Chapter 7; 32 m (7.3 design matters threshold)",
     TRUE, src("7.3"), "HCC ODP 7 Central City Zone", coverage = 0.7, coverage_source = src("7.4.1"),
     landscaping = 0.2, landscaping_source = src("7.4.2: permeable surface 20%")),
  bz("CC3", "Central City Ferrybank", "Central City Zone, Precinct 3 (Ferrybank)", 32,
     "Assumption: no maximum height in Chapter 7; 32 m (7.3 design matters threshold)",
     TRUE, src("7.3"), "HCC ODP 7 Central City Zone", coverage = 0.8, coverage_source = src("7.4.1"),
     landscaping = 0.2, landscaping_source = src("7.4.2: permeable surface 20%")),
  bz("KNZ", "Knowledge", "Knowledge Zone", 15, src("8.4.8: 15 m (20% of a footprint may reach 20 m)"), FALSE,
     src("8.3: residential units not provided for"), "HCC ODP 8 Knowledge Zone",
     coverage = 0.5, coverage_source = src("8.4.3"), landscaping = 0.2, landscaping_source = src("8.4.4: permeable 20%")),
  bz("IND", "Industrial", "Industrial Zone", 20, src("9.4.2"), FALSE, src("9.3: residential activity not provided for"),
     "HCC ODP 9 Industrial Zone", landscaping = 0.1, landscaping_source = src("9.4.5: permeable 10%"), storey_height = IND_STOREY),
  bz("RLZ", "Ruakura Logistics", "Ruakura Logistics Zone", 20, src("10.4.5"), FALSE, src("10.3"),
     "HCC ODP 10 Ruakura Logistics Zone", coverage = 0.8, coverage_source = src("10.4.3"),
     landscaping = 0.1, landscaping_source = src("10.4.4: permeable 10%"), storey_height = IND_STOREY),
  bz("RIPZ", "Ruakura Industrial Park", "Ruakura Industrial Park Zone", 20, src("11.4.4"), FALSE, src("11.3"),
     "HCC ODP 11 Ruakura Industrial Park Zone", coverage = 0.75, coverage_source = src("11.4.6"),
     landscaping = 0.2, landscaping_source = src("11.4.7"), storey_height = IND_STOREY),
  bz("TRNZ", "Te Rapa North Industrial", "Te Rapa North Industrial Zone", 20, src("12.4.2 (Stage 1A exceptions unmodelled)"),
     FALSE, src("12.3"), "HCC ODP 12 Te Rapa North Industrial Zone",
     landscaping = 0.2, landscaping_source = src("12.4.5: permeable 20%"), storey_height = IND_STOREY)
)
others <- rbind(none("CFZ", "Community Facilities Zone", "Community Facilities"),
                none("MFZ", "Major Facilities Zone", "Major Facilities"),
                none("OSZ", "Open Space Zones", "Open Space"),
                none("KNU", "Knowledge Zone, University of Waikato Campus (concept plan)", "Knowledge University"),
                none("TRND", "Te Rapa North Industrial Zone, Deferred", "Te Rapa North Deferred"),
                none("RTC", "Rototuna Town Centre Zone (development plans)", "Rototuna Town Centre"),
                none("FUZ", "Future Urban Zone", "Future Urban"),
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
  id = c("infrastructure_grz", "infrastructure_mrz", "gully_hazard", "amenity_protection", "peacocke_height",
         "built_heritage", "heritage_area", "natural_area", "flood_high"),
  label = c("Three Waters Infrastructure Capacity Overlay (General Residential)",
            "Three Waters Infrastructure Capacity Overlay (Medium Density Residential)",
            "Waikato Riverbank and Gully Hazard Area", "Industrial Amenity Protection Area",
            "Peacocke Increased Height Overlay", "Built heritage (Schedule 8A), the scheduled site",
            "Historic Heritage Area (Schedule 8D)", "Significant Natural Area (Schedule 9C)",
            "High Flood Hazard Area, PC14 (proposed)"),
  type = c("parameters", "parameters", "exclusion", "parameters", "parameters",
           "exclusion", "parameters", "exclusion", "exclusion"),
  layer = c("infrastructure_capacity", "infrastructure_capacity", "gully_hazard", "amenity_protection", "peacocke_height",
            "built_heritage", "heritage_area", "natural_area", "flood_high"),
  combine = c("replace", "replace", NA, "replace", "replace", NA, "replace", NA, NA),
  removes = c(NA, NA, "all", NA, NA, "all", NA, "all", "all"),
  buffer = c(NA, NA, "6", NA, NA, NA, NA, NA, NA),
  applies_to_zones = c("GRZ", "MRZ", NA, "IND", "PMRZ", NA, "GRZ, MRZ, HDZ, LLRZ", NA, NA),
  source = c(src("4.2.5.1: density inside the Three Waters Infrastructure Capacity Overlay"),
             src("4.3.4.1: density inside the Three Waters Infrastructure Capacity Overlay"),
             src("22.3, 22.2.1l: new buildings D and vulnerable use to avoid the area; 4.2.5.6, 4.3.4.6, 4.4.5.6, 4A R38, 6.4.3: 6 m setback"),
             src("9.4.2, 9.4.4: 10 m and 75% coverage in the Amenity Protection Area"),
             src("4A R37: 16 m in the Increased Height Overlay (PC5 High Density Overlay Area layer)"),
             src("19.3.1: demolition of A ranked items NC, B ranked D; new buildings on the site D or RD (PC9)"),
             src("19.3.2, 19.4.3-19.4.7: residential zoned Historic Heritage Areas (PC9)"),
             src("20.3: new buildings in a Significant Natural Area not provided for (D in cSNA, NC in fSNA)"),
             "HCC ODP 22.3 h, ff as amended by Plan Change 14 (Flooding), PROPOSED: new buildings and residential activity NC in the High Flood Hazard Area (officer's rebuttal version, 12 Sep 2025; decision 24 Dec 2025 under appeal); Floodviewer hazard factor 4"),
  stringsAsFactors = FALSE)
put("overlays", ov)

# ---- areas: residential precincts --------------------------------------------------------------
ar <- data.frame(id = "rotokauri_north", label = "Rotokauri North Residential Precinct", layer = "precincts",
                 filter = "Name=Rotokauri North Residential Precinct", applies_to_zones = "MRZ", combine = "replace",
                 source = src("4.3.4.4 b, 4.3.4.6 m-o: Rotokauri North Residential Precinct"), stringsAsFactors = FALSE)
put("areas", ar)
ch <- data.frame(target = c("overlay:infrastructure_grz", "overlay:infrastructure_mrz", "area:rotokauri_north",
                            "overlay:amenity_protection", "overlay:peacocke_height", "overlay:heritage_area"),
                 method = c("hybrid", "hybrid", NA, NA, NA, "hybrid"),
                 site_area_per_dwelling = c(200, 150, NA, NA, NA, NA),
                 max_dwellings_per_site = c(NA, NA, NA, NA, NA, 1),
                 minor_dwellings_per_site = c(NA, NA, NA, NA, NA, 1),
                 density_source = c(src("4.2.5.1: average net site area 200 m2 per unit"), src("4.3.4.1: average net site area 150 m2 per unit"), NA, NA, NA,
                                    src("19.3.2: one single residential unit per site RD (two or more D; apartments, terraces, duplexes NC); ancillary unit RD")),
                 height = c(NA, NA, 11, 10, 16, 8), occupiable = c(NA, NA, 11, 10, 16, 8), storeys = c(NA, NA, NA, NA, 5, 2),
                 height_source = c(NA, NA, src("4.3.4.4 b: Rotokauri North Residential Precinct 11 m"), src("9.4.2 b"),
                                   src("4A R37: 16 m in the Increased Height Overlay; storeys follow the height"),
                                   src("19.4.6: rear sites 8 m and two storeys, used for all sites (front sites take the original or neighbouring height)")),
                 coverage_max = c(NA, NA, NA, 0.75, NA, 0.35), coverage_max_source = c(NA, NA, NA, src("9.4.4"), NA, src("19.4.4")),
                 landscaping_min = c(NA, NA, NA, NA, NA, 0.4), landscaping_min_source = c(NA, NA, NA, NA, NA, src("19.4.5: permeable 40%")),
                 stringsAsFactors = FALSE)
put("changes", ch)
rows2 <- list(sb("area:rotokauri_north", "upper_level", "rear", distance = 8, above_height = 5,
                 source = src("4.3.4.6 m: rear yard 8 m for a building over 5 m (four or more units)")),
              sb("overlay:heritage_area", "plane", "side, rear", angle_deg = 45, start_height = 3, angle_by_bearing = "135-225:28",
                 source = src("19.4.7: 28 degrees between north-west and north-east, 45 degrees otherwise, from 3 m")),
              sb("overlay:heritage_area", "plane", "road", angle_deg = 45, start_height = 3,
                 source = src("19.4.7 c: 45 degrees along a transport corridor")))

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
SOUTH <- "135-225:28"
RES_OS <- "RESIDENTIAL, OPEN_SPACE"
biz_hirb <- function(z, rule) list(
  sb(z, "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ, LLRZ", source = src(paste0(rule, ": adjoining General Residential"))),
  sb(z, "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "MRZ, PMRZ, HDZ", source = src(paste0(rule, ": adjoining Medium Density Residential")))
)
ind_hirb <- function(z, rule) sb(z, "plane", "side, rear", angle_deg = 45, start_height = 3, adjacent_zones = RES_OS,
                                 angle_by_bearing = SOUTH, source = src(paste0(rule, ": 45 degrees (28 degrees on the southern boundary) from 3 m")))
rows3 <- c(
  # Business 1, 3, 4, 5, 7 (6.4.2, 6.4.3).
  unlist(lapply(c("B1", "B3", "B4", "B4I", "B5", "B7"), function(z) c(
    list(sb(z, "yard", ART, distance = 5, source = src("6.4.3: 5 m fronting an arterial transport corridor"))),
    biz_hirb(z, "6.4.2"))), recursive = FALSE),
  lapply(c("B1", "B5", "B7"), function(z) sb(z, "yard", "side, rear", distance = 5, adjacent_zones = "RESIDENTIAL",
                                               source = src("6.4.3: 5 m where the boundary adjoins a Residential Zone"))),
  lapply(c("B4", "B4I"), function(z) sb(z, "yard", "side, rear", distance = 5, not_adjacent_zones = "B4, B4I",
                                          source = src("6.4.3: Business 4, 5 m except internal Business 4 boundaries"))),
  # Peacocke centres (6A R47, R48; 6B R40-R42).
  list(sb("PNCZ", "upper_level", "road", distance = 3, above_height = 12, source = src("6A R47: top storey above 12 m set back 3 m from the transport corridor")),
       sb("PNCZ", "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "PMRZ, MRZ", source = src("6A R47")),
       sb("PNCZ", "yard", "side, rear", distance = 1.5, adjacent_zones = "PMRZ, MRZ", source = src("6A R48")),
       sb("PLCZ", "upper_level", "road", distance = 3, above_height = 12, source = src("6B R41")),
       sb("PLCZ", "upper_level", "side, rear", distance = 30, above_height = 16, adjacent_zones = RES_OS,
          source = src("6B R40: 16 m within 30 m of a Residential or Open Space Zone (as a 30 m setback above 16 m from those boundaries)")),
       sb("PLCZ", "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "PMRZ, MRZ", source = src("6B R41")),
       sb("PLCZ", "yard", "side, rear", distance = 3, adjacent_zones = "RESIDENTIAL", source = src("6B R42"))),
  # Central City (7.4.4, 7.4.6): the adjoining residential zone's plane.
  unlist(lapply(c("CC1", "CC2", "CC3"), function(z) list(
    sb(z, "plane", "side, rear", angle_deg = 45, start_height = 4, adjacent_zones = "GRZ", source = src("7.4.4: the General Residential plane (4.2.5.5)")),
    sb(z, "plane", "side, rear", angle_deg = 60, start_height = 4, adjacent_zones = "MRZ, HDZ", source = src("7.4.4: the Medium and High Density plane (4.3.4.5, 4.4.5.5)")))),
    recursive = FALSE),
  list(sb("CC2", "yard", "side, rear", distance = 1.5, adjacent_zones = "GRZ", source = src("7.4.6: the adjoining zone's side setback")),
       sb("CC2", "yard", "side, rear", distance = 1, adjacent_zones = "MRZ, HDZ", source = src("7.4.6: the adjoining zone's side setback")),
       sb("CC3", "yard", "road", distance = 3, source = src("7.4.6")),
       sb("CC3", "yard", "side", distance = 3, source = src("7.4.6")),
       sb("CC3", "yard", "rear", distance = 5, source = src("7.4.6"))),
  # Knowledge (8.4.6, 8.4.7).
  list(sb("KNZ", "yard", "road", distance = 5, source = src("8.4.6: local and collector transport corridors")),
       sb("KNZ", "yard", ART, distance = 15, source = src("8.4.6: arterial transport corridors")),
       sb("KNZ", "yard", "side, rear", distance = 8, adjacent_zones = RES_OS, source = src("8.4.6")),
       sb("KNZ", "plane", "side, rear", angle_deg = 45, start_height = 3, not_adjacent_zones = "KNZ, KNU",
          source = src("8.4.7: 45 degrees from 3 m at the boundary of any adjoining zone"))),
  # Industrial (9.4.1, 9.4.3).
  list(sb("IND", "yard", "road", distance = 3, source = src("9.4.1: local and collector transport corridors")),
       sb("IND", "yard", ART, distance = 5, source = src("9.4.1: arterial transport corridors")),
       sb("IND", "plane", ART, angle_deg = 45, start_height = 5, source = src("9.4.1, Figure 9.4.1b: 45 degrees from 5 m on an arterial boundary")),
       sb("IND", "yard", "side, rear", distance = 8, adjacent_zones = "RESIDENTIAL", source = src("9.4.1")),
       sb("IND", "yard", "side, rear", distance = 3, adjacent_zones = "OPEN_SPACE", source = src("9.4.1")),
       ind_hirb("IND", "9.4.3")),
  # Ruakura Logistics (10.4.6), Ruakura Industrial Park (11.4.3, 11.4.5), Te Rapa North (12.4.1, 12.4.3).
  list(sb("RLZ", "yard", "road", distance = 10, source = src("10.4.6")),
       sb("RIPZ", "yard", "road", distance = 5, source = src("11.4.3")),
       sb("RIPZ", "yard", ART, distance = 15, source = src("11.4.3")),
       sb("RIPZ", "yard", "side, rear", distance = 8, adjacent_zones = "OPEN_SPACE", source = src("11.4.3")),
       sb("RIPZ", "yard", "side, rear", distance = 40, adjacent_zones = "RESIDENTIAL", source = src("11.4.3")),
       ind_hirb("RIPZ", "11.4.5"),
       sb("TRNZ", "yard", "road", distance = 5, source = src("12.4.1")),
       sb("TRNZ", "yard", ART, distance = 15, source = src("12.4.1")),
       sb("TRNZ", "yard", "side, rear", distance = 10, source = src("12.4.1: 10 m from all boundaries other than transport corridors")),
       ind_hirb("TRNZ", "12.4.3"))
)
rows <- c(rows, rows2, rows3)
cols <- unique(unlist(lapply(rows, names)))
setbacks <- do.call(rbind, lapply(rows, function(r) { for (cc in setdiff(cols, names(r))) r[[cc]] <- NA; r[, cols] }))
put("setbacks", setbacks)

# ---- bands: residential share by storey in Business 6 -----------------------------------------
gf <- c("B6G", "B6M", "B1", "B3", "B5", "PNCZ", "PLCZ")
bands <- data.frame(target = rep(gf, each = 2), rule = "residential_share", by = "storey",
                    upper = rep(c(1, NA), length(gf)), value = rep(c(0, 1), length(gf)),
                    source = rep(c(src("6.4.7 b, 6A R51, 6B R45: no residential activity at ground floor"), NA), length(gf)))
put("bands", bands)

# ---- families --------------------------------------------------------------------------------
fam <- data.frame(family = c("RESIDENTIAL", "BUSINESS", "OPEN_SPACE"),
                  zones = c("GRZ, MRZ, HDZ, LLRZ, PMRZ",
                            "B1, B2, B3, B4, B4I, B5, B6G, B6M, B7, PNCZ, PLCZ, CC1, CC2, CC3, RTC", "OSZ"))
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
           "Rotokauri North: other precinct standards (front yard, site-wide density)",
           "Business height overlay (Figure 6.4c): 26 m and 4:1",
           "Central City: no maximum height; street wall (13 m then 4 m back), Garden Place sunlight plane, Riverfront Overlay 5 m",
           "Rototuna Town Centre Zone",
           "Knowledge Zone: University of Waikato precinct; 20% of a footprint to 20 m; rail setback",
           "Business 7: residential above ground floor in the Frankton Living Overlay",
           "Industrial: Rotokauri Employment Area (15 m, 75%); expressway and rail setbacks",
           "Te Rapa North: Stage 1A heights, river and stream setbacks; the Deferred Industrial sub-zone",
           "Peacocke centres: bat habitat 5 m setback",
           "Business 4 height by adjacency, Peacocke Local Centre 16 m within 30 m of zones",
           "Industrial storey height",
           "Historic Heritage Areas: front-site height, rear-site 40% coverage, business-zoned HHAs",
           "Built heritage: the extent of place",
           "Operative flood hazard maps; PC14 Medium, Low, Depression and Overland Flow Path areas",
           "Notable trees and their root protection zones; archaeological and cultural sites"),
  reason = c("A single envelope per site does not place separate buildings or balconies.",
             "Depend on where buildings, windows and planting go, which a blank-slate envelope does not know.",
             "These require a minimum intensity; they do not cap capacity.",
             "Needs a rear lane, which the extract does not identify.",
             "The 60% terrace and apartment coverage is used; the height overlay and bat habitat layers are not held.",
             "The area is not mapped as a layer.",
             "Staging, structure plan and expressway rules that depend on infrastructure delivery or on layers not held.",
             "Only the 11 m height and the 8 m rear yard above 5 m are entered.",
             "No layer for the overlay; the zone heights and ratios are used.",
             "32 m is used as an assumption; the overlays are not mapped. The true limit is the RD assessment of each building.",
             "Buildings are D under development plans; precincts are figures in Appendix 7 with no layer; no height standard.",
             "Campus concept plan with no maximum height (method none); the 20 m allowance is small.",
             "The overlay is not mapped; residential activity is D elsewhere in the zone.",
             "The employment area and the designations are not held as layers.",
             "Stage areas and river banks are not held; deferred land is not yet live.",
             "No bat habitat layer is used in the centres.",
             "Coded by adjacency in prepare.R (Business 4 within 30 m of the Industrial Zone) and as a 30 m upper-level setback from zone boundaries, which misses zones across a road.",
             "Assumption, not a plan rule: industrial, logistics and industrial park zones use a 7 m storey (two storeys under 20 m), not the 3 m default.",
             "Front sites take the original or neighbouring building height, which a blank slate does not know; 8 m (the rear-site limit) is used. Business-zoned HHAs only control street-front demolition (D) and fences.",
             "The whole parcel holding a scheduled item is excluded, not just the extent of place.",
             "PC14 replaces the operative maps (user's choice to apply it as proposed); Medium is RD and Low, Depression and Overland Flow Path areas are P, with floor level standards that do not cap capacity.",
             "Points and small areas whose effect on an envelope depends on where the building goes."),
  zones = c("GRZ, MRZ, HDZ", "GRZ, MRZ, HDZ", "MRZ, HDZ, B6G, B6M", "GRZ, MRZ", "PMRZ", "LLRZ",
            "GRZ, MRZ, LLRZ", "MRZ", "B1, B2, B3, B4, B6G, B6M, B7", "CC1, CC2, CC3", "RTC", "KNZ, KNU", "B7",
            "IND", "TRNZ, TRND", "PNCZ, PLCZ", "B4, B4I, PLCZ", "IND, RLZ, RIPZ, TRNZ",
            "GRZ, MRZ, HDZ, LLRZ", NA, NA, NA),
  likely_effect = c("overstates", "overstates", "either", "understates", "either", "overstates", "either", "either",
                    "understates", "either", "understates", "understates", "understates", "overstates", "either",
                    "overstates", "either", "either", "either", "understates", "either", "overstates"),
  source = c(src("4.2.5.6, 4.3.4.6, 4.4.5.6"), src("4.2.5.3, 4.2.5.9, 4.2.5.10, 4.2.5.13 and equivalents"),
             src("4.3.4.1, 4.4.5.1, 6.4.7"), src("4.2.5.2 b, 4.3.4.2 b"), src("4A R34, R37, R38"),
             src("4.5.4.1"), src("4.2, 4.3 precinct rules"), src("4.3.4.6 m-o"),
             src("6.4.1, 6.4.4, Figure 6.4c"), src("7.3, 7.4.5, 7.4.6, 7.4.11"), src("13.4, 13.5"),
             src("8.4.6, 8.4.8, 8.6"), src("6.3"), src("9.4.1, 9.4.2, 9.4.4"), src("12.4.1, 12.4.2"),
             src("6A R48, 6B R42"), src("6.4.1, 6B R40"), "Assumption",
             src("19.4.4, 19.4.6, 19.3.2"), src("19.3.1"), src("22.3; PC14 (proposed)"), src("19.3.3, 20.3, 25.2")))
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
