# Fetch the Hamilton extract for the "Adding a new jurisdiction" walkthrough.
#
# Run FROM THE capacityengine FOLDER (its LINZ downloader and settings):
#   Rscript ../plancap/data-raw/hamilton/fetch.R
#
# Writes ../plancap/data-raw/cache/hamilton/ (git-ignored):
#   * zoning.gpkg: Hamilton City Council's District Plan Zones
#     (DistrictPlan_Zoning FeatureServer, the Operative District Plan with
#     Plan Change 12) over the extract;
#   * parcels.gpkg: LINZ NZ Primary Parcels (layer 50772, CC BY 4.0).
# The council's zoning is not redistributed with the package: its open data
# entry states no licence ("check with source agency").

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
out <- "../plancap/data-raw/cache/hamilton"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# About 1.4 km square over Claudelands and Hamilton East, between the
# central city's high density ring and the Five Cross Roads medium density
# area.
centre <- sf::st_transform(sf::st_sfc(sf::st_point(c(175.2897, -37.7815)), crs = 4326), 2193)
xy <- sf::st_coordinates(centre)
half <- 700
bb <- sf::st_bbox(c(xmin = xy[1] - half, ymin = xy[2] - half, xmax = xy[1] + half, ymax = xy[2] + half),
                  crs = sf::st_crs(2193))
env <- paste(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]], sep = ",")
q <- paste0("https://services1.arcgis.com/R6s0QqCMQdwKY6yp/arcgis/rest/services/DistrictPlan_Zoning/FeatureServer/0/query",
            "?where=1%3D1&geometry=", env,
            "&geometryType=esriGeometryEnvelope&inSR=2193&spatialRel=esriSpatialRelIntersects",
            "&outFields=Zoning_1,Sub_Zone,Zone_Description&outSR=2193&f=geojson")
zones <- sf::st_read(q, quiet = TRUE)
sf::st_crs(zones) <- 2193
zones <- sf::st_make_valid(zones)
sf::st_write(zones, file.path(out, "zoning.gpkg"), delete_dsn = TRUE, quiet = TRUE)
cat(nrow(zones), "zone polygons\n")
print(table(zones$Zone_Description))

parcels <- load_linz_layer("primary_parcels", bb, cache_dir = out)
parcels <- sf::st_transform(parcels, 2193)
sf::st_write(parcels, file.path(out, "parcels.gpkg"), delete_dsn = TRUE, quiet = TRUE)
cat(nrow(parcels), "parcels\n")
print(table(parcels$parcel_intent))
