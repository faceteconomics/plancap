# Fetch a Hamilton extract for plancap.
#
# Run FROM THE capacityengine FOLDER (its LINZ downloader and settings):
#   Rscript ../plancap/data-raw/hamilton/fetch.R            # the Claudelands walkthrough extract
#   Rscript ../plancap/data-raw/hamilton/fetch.R peacocke   # another named extract (see `extracts`)
#
# Writes ../plancap/data-raw/cache/hamilton/ (the walkthrough extract) or
# ../plancap/data-raw/cache/hamilton/<name>/ (git-ignored):
#   * zoning.gpkg: Hamilton City Council's District Plan Zones
#     (DistrictPlan_Zoning FeatureServer, the Operative District Plan with
#     Plan Change 12);
#   * infrastructure_capacity.gpkg, precincts.gpkg: the PC12 Three Waters
#     Infrastructure Capacity Overlay and Precincts (eplan_pc12_amendments_data);
#   * gully_hazard.gpkg: the Waikato Riverbank and Gully Hazard Area;
#   * centrelines.gpkg: the road hierarchy (RoadHierarchy20260623), for the
#     arterial setback;
#   * parcels.gpkg: LINZ NZ Primary Parcels (layer 50772, CC BY 4.0).
# The council's layers are not redistributed with the package: its open data
# entries state no licence ("check with source agency").

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
name <- if (length(args)) args[[1]] else "claudelands"
extracts <- list(
  # About 1.4 km square over Claudelands and Hamilton East, between the
  # central city's high density ring and the Five Cross Roads medium density area.
  claudelands = c(175.2897, -37.7815, 700),
  # Peacocke: the Medium Density Residential Zone (Chapter 4A) and its gullies.
  peacocke = c(175.3120, -37.8260, 900),
  # Ruakura: the Large Lot Residential Zone east of the university.
  ruakura = c(175.3330, -37.7810, 700),
  # H2: Frankton and the central city's west (Business 7, City Living, Industrial).
  frankton = c(175.2686, -37.7870, 900),
  # The Base (Business 3 and 4) and Te Rapa's Industrial Zone.
  thebase = c(175.2350, -37.7440, 900),
  # Te Rapa North Industrial.
  terapa = c(175.2160, -37.7230, 900),
  # The Knowledge Zone and the University of Waikato.
  university = c(175.3139, -37.7809, 900),
  # H3: the whole city (the District Plan zoning's extent; parcels outside
  # the zoning are dropped in prepare.R).
  city = c(NA, NA, NA)
)
e <- extracts[[name]]
if (is.null(e)) stop("Unknown extract ", name, "; one of ", paste(names(extracts), collapse = ", "))
out <- file.path("../plancap/data-raw/cache/hamilton", if (name == "claudelands") "" else name)
dir.create(out, recursive = TRUE, showWarnings = FALSE)

if (name == "city") {
  bb <- sf::st_bbox(c(xmin = 1792450, ymin = 5808750, xmax = 1806460, ymax = 5825265), crs = sf::st_crs(2193))
} else {
  centre <- sf::st_transform(sf::st_sfc(sf::st_point(e[1:2]), crs = 4326), 2193)
  xy <- sf::st_coordinates(centre)
  half <- e[[3]]
  bb <- sf::st_bbox(c(xmin = xy[1] - half, ymin = xy[2] - half, xmax = xy[1] + half, ymax = xy[2] + half),
                    crs = sf::st_crs(2193))
}

base <- "https://services1.arcgis.com/R6s0QqCMQdwKY6yp/arcgis/rest/services/"
# One layer over the extract, paged 1,000 features at a time.
arcgis <- function(path, fields, file, pad = 0, where = "1=1") {
  env <- paste(bb[["xmin"]] - pad, bb[["ymin"]] - pad, bb[["xmax"]] + pad, bb[["ymax"]] + pad, sep = ",")
  pages <- list()
  offset <- 0
  repeat {
    q <- paste0(base, path, "/query?where=", utils::URLencode(where, reserved = TRUE), "&geometry=", env,
                "&geometryType=esriGeometryEnvelope&inSR=2193&spatialRel=esriSpatialRelIntersects",
                "&outFields=", fields, "&outSR=2193",
                "&resultOffset=", offset, "&resultRecordCount=1000&f=geojson")
    tmp <- tempfile(fileext = ".geojson")
    utils::download.file(q, tmp, quiet = TRUE, mode = "wb")
    x <- sf::st_read(tmp, quiet = TRUE)
    if (!nrow(x)) break
    sf::st_crs(x) <- 2193
    pages[[length(pages) + 1]] <- x
    if (nrow(x) < 1000) break
    offset <- offset + 1000
  }
  x <- if (length(pages)) do.call(rbind, pages) else sf::st_sf(geometry = sf::st_sfc(crs = 2193))
  if (!all(sf::st_geometry_type(x) %in% c("LINESTRING", "MULTILINESTRING"))) x <- sf::st_make_valid(x)
  sf::st_write(x, file.path(out, file), delete_dsn = TRUE, quiet = TRUE)
  cat(file, ":", nrow(x), "features\n")
  invisible(x)
}

zones <- arcgis("DistrictPlan_Zoning/FeatureServer/0", "Zoning_1,Sub_Zone,Zone_Description", "zoning.gpkg")
print(table(zones$Zone_Description))
arcgis("eplan_pc12_amendments_data/FeatureServer/130", "OBJECTID", "infrastructure_capacity.gpkg")
pr <- arcgis("eplan_pc12_amendments_data/FeatureServer/141", "Name,Type", "precincts.gpkg")
print(table(pr$Name))
arcgis("GEOTECH_AND_HYDRO___DP_Waikato_River_Gully_Hazard_Area/FeatureServer/0", "Hazard_Fac", "gully_hazard.gpkg")
# Peacocke's Increased Height Overlay (PC5's "High Density Overlay Area").
arcgis("PC12_Features/FeatureServer/24", "LandUse", "peacocke_height.gpkg")
# Centre lines a little beyond the extract, so edge sites find their road.
rd <- arcgis("RoadHierarchy20260623/FeatureServer/0", "FIRST_ROAD_NAME,FIRST_Road_Classification",
             "centrelines.gpkg", pad = 100)
print(table(rd$FIRST_Road_Classification))
# H3: heritage, natural areas (Plan Change 9) and the PC14 High Flood Hazard
# Area (Floodviewer hazard factor 4, both scenarios and both models).
arcgis("eplan_pc9_data/FeatureServer/81", "Name,ReferenceNo,Ranking", "built_heritage_points.gpkg")
arcgis("eplan_pc9_data/FeatureServer/94", "Name", "heritage_area.gpkg")
arcgis("eplan_pc9_amendments_data/FeatureServer/135", "Site_Id,Sna_Type", "natural_area.gpkg")
f1 <- arcgis("hazards_HCC_OneHundredYear_FloodHazards/FeatureServer/0", "Hazard_Factor,Climate_Change_Type",
             "flood_high_catchment.gpkg", where = "Hazard_Factor=4")
f2 <- arcgis("hazards_HCC_WaikatoRiverGullyAreaFloodHazard/FeatureServer/0", "Hazard_Factor",
             "flood_high_river.gpkg", where = "Hazard_Factor=4")

parcels <- load_linz_layer("primary_parcels", bb, cache_dir = out)
parcels <- sf::st_transform(parcels, 2193)
sf::st_write(parcels, file.path(out, "parcels.gpkg"), delete_dsn = TRUE, quiet = TRUE)
cat(nrow(parcels), "parcels\n")
print(table(parcels$parcel_intent))
