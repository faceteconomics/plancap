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
plan,name,"Hamilton City Operative District Plan (residential zones and Business 6, walkthrough extract)"
plan,id,hamilton-odp-2026
plan,jurisdiction,Hamilton
plan,country,NZ
plan,effective_date,2026-11-13
plan,units,m
plan,source,"Hamilton City Operative District Plan, ePlan revision 13 November 2026 (Plan Change 12 operative 20 December 2024)"
plan,notes,"Entered through the Excel template for the Adding a new jurisdiction vignette: General, Medium and High Density Residential, Business 6 and Business 2 only."
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
zones$far_max <- c(NA, NA, NA, 2, 3, 2)
zones$far_max_source <- c(NA, NA, NA, src("6.4.4"), src("6.4.4"), src("6.4.4"))
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

# ---- setbacks ---------------------------------------------------------------------------
sb <- function(target, kind, boundaries, ..., source) {
  data.frame(target = target, kind = kind, boundaries = boundaries, ..., source = source, stringsAsFactors = FALSE)
}
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
                  zones = c("GRZ, MRZ, HDZ", "B6G, B6M, B2", "OSZ"))
put("families", fam)

# ---- unmodelled ------------------------------------------------------------------------------
um <- data.frame(
  rule = c("Arterial transport corridor setback (5 m)",
           "Density within the Three Waters Infrastructure Capacity Overlay",
           "Separation between residential buildings on a site; upper-floor balcony setbacks",
           "Outlook space, outdoor living area, front landscaping, tree canopy, wall articulation",
           "Waikato Riverbank and Gully Hazard Area setback (6 m)",
           "Maximum average net site area (MRZ, HDZ) and minimum residential density (Business 6)",
           "Building coverage of 60% for terraces and apartments with rear-lane parking"),
  reason = c("Needs the transport corridor hierarchy; the local and collector setback is applied to every road.",
             "The overlay layer is not held; outside it there is no density standard.",
             "A single envelope per site does not place separate buildings or balconies.",
             "Depend on where buildings, windows and planting go, which a blank-slate envelope does not know.",
             "The hazard area layer is not held.",
             "These require a minimum intensity; they do not cap capacity.",
             "Needs a rear lane, which the extract does not identify."),
  zones = c("GRZ, MRZ, HDZ, B6G, B6M, B2", "GRZ, MRZ", "GRZ, MRZ, HDZ", "GRZ, MRZ, HDZ", "GRZ, MRZ, HDZ, B6G, B6M, B2",
            "MRZ, HDZ, B6G, B6M", "GRZ, MRZ"),
  likely_effect = c("overstates", "overstates", "overstates", "overstates", "overstates", "either", "understates"),
  source = c(src("4.2.5.6, 4.3.4.6, 4.4.5.6, 6.4.3"), src("4.2.5.1, 4.3.4.1"), src("4.2.5.6, 4.3.4.6, 4.4.5.6"),
             src("4.2.5.3, 4.2.5.9, 4.2.5.10, 4.2.5.13 and equivalents"), src("4.2.5.6, 4.3.4.6, 4.4.5.6, 6.4.3"),
             src("4.3.4.1, 4.4.5.1, 6.4.7"), src("4.2.5.2 b, 4.3.4.2 b")))
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
         "# General, Medium and High Density Residential, Business 6 and Business 2 only;",
         "# check the plan itself before relying on any value.", "")
writeLines(c(hdr, readLines("inst/rulebooks/hamilton.yaml")), "inst/rulebooks/hamilton.yaml")
