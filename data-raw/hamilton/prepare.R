# Prepare a Hamilton extract for plancap: zone codes the rulebook maps,
# parcels split into land and roads, the overlay layers and the road centre
# lines. Sourced by run.R and the vignette's source (vignettes/hamilton.Rmd.orig).

hamilton_inputs <- function(dir = "data-raw/cache/hamilton") {
  z0 <- sf::st_read(file.path(dir, "zoning.gpkg"), quiet = TRUE)
  # The Industrial Amenity Protection Area is an overlay stored with the zones
  # (a parameters overlay in the rulebook), and the Transport Corridor Zone is
  # one polygon under every other zone; roads come from the road parcels.
  apa <- z0[z0$Zone_Description %in% "Industrial Amenity Protection Area", 0]
  z <- z0[!is.na(z0$Zone_Description) & !grepl("Amenity Protection|Transport Corridor", z0$Zone_Description), ]
  # The council's polygons overlap in slivers (Peacocke); the first keeps each overlap.
  z <- suppressWarnings(sf::st_collection_extract(sf::st_difference(z), "POLYGON"))
  d <- z$Zone_Description
  # First match wins: Peacocke's zone names contain the general ones, and the
  # Knowledge and Te Rapa North sub-zones come before their zones.
  codes <- c("Peacocke Medium Density Residential" = "Peacocke Medium Density Residential",
             "Peacocke Local Centre" = "Peacocke Local Centre",
             "Peacocke Neighbourhood" = "Peacocke Neighbourhood Centre",
             "Large Lot Residential" = "Large Lot Residential",
             "General Residential" = "General Residential",
             "Medium Density Residential" = "Medium Density Residential",
             "High Density Residential" = "High Density Residential",
             "Business 1 Zone" = "Business 1",
             "Business 2 Zone" = "Business 2",
             "Business 3 Zone" = "Business 3",
             "Business 4 Zone" = "Business 4",
             "Business 5 Zone" = "Business 5",
             "Business 6 Zone" = "Business 6",
             "Business 7 Zone" = "Business 7",
             "Downtown Precinct" = "Central City Downtown",
             "City Living Precinct" = "Central City City Living",
             "Ferrybank Precinct" = "Central City Ferrybank",
             "Ruakura Open Space" = "Open Space",
             "University of Waikato" = "Knowledge University",
             "^Knowledge" = "Knowledge",
             "^Logistics" = "Ruakura Logistics",
             "^Ruakura Industrial Park" = "Ruakura Industrial Park",
             "Deferred Industrial" = "Te Rapa North Deferred",
             "^Te Rapa North" = "Te Rapa North Industrial",
             "^Industrial" = "Industrial",
             "Rototuna Town Centre" = "Rototuna Town Centre",
             "Future Urban" = "Future Urban",
             "Community Facilities" = "Community Facilities",
             "Major Facilities" = "Major Facilities",
             "^Open Space" = "Open Space")
  z$zone <- NA_character_
  for (k in names(codes)) z$zone[is.na(z$zone) & grepl(k, d)] <- codes[[k]]
  if (anyNA(z$zone)) warning("Zone descriptions with no code: ", paste(unique(d[is.na(z$zone)]), collapse = "; "))
  # Business 6's height and floor area ratio depend on the residential zone it
  # adjoins (6.4.1, 6.4.4): code each centre polygon by its neighbour, Medium
  # Density where it touches any. Business 4 is 20 m where it adjoins the
  # Industrial Zone (6.4.1).
  near <- function(i, to) lengths(sf::st_is_within_distance(z[i, ], z[z$zone %in% to, ], 30)) > 0
  b6 <- which(z$zone %in% "Business 6")
  z$zone[b6] <- ifelse(near(b6, "Medium Density Residential"),
                       "Business 6 (Medium Density Residential)", "Business 6 (General Residential)")
  b4 <- which(z$zone %in% "Business 4")
  z$zone[b4] <- ifelse(near(b4, "Industrial"), "Business 4 (Industrial)", "Business 4")
  p <- sf::st_read(file.path(dir, "parcels.gpkg"), quiet = TRUE)
  p$parcel_id <- as.character(p$id)
  land <- p[!p$parcel_intent %in% c("Road", "Hydro", "Railway"), "parcel_id"]
  # Parcels outside the city's zoning (the city-wide extract's box reaches
  # into Waikato and Waipaa districts) are dropped.
  inside <- lengths(sf::st_intersects(sf::st_point_on_surface(sf::st_geometry(land)), z0)) > 0
  land <- land[inside, ]
  roads <- p[p$parcel_intent %in% "Road", 0]
  layer <- function(f) {
    f <- file.path(dir, paste0(f, ".gpkg"))
    if (file.exists(f)) sf::st_read(f, quiet = TRUE) else NULL
  }
  # Built heritage items are points: the parcels holding them are the
  # scheduled sites. The PC14 High Flood Hazard Area joins the catchment and
  # river models.
  pts <- layer("built_heritage_points")
  bh <- if (!is.null(pts) && nrow(pts)) land[lengths(sf::st_intersects(land, pts)) > 0, 0] else NULL
  fl <- Filter(function(x) !is.null(x) && nrow(x), list(layer("flood_high_catchment"), layer("flood_high_river")))
  flood <- if (length(fl)) do.call(rbind, lapply(fl, function(x) x[, 0])) else NULL
  layers <- Filter(Negate(is.null), list(infrastructure_capacity = layer("infrastructure_capacity"),
                                         built_heritage = bh, heritage_area = layer("heritage_area"),
                                         natural_area = layer("natural_area"), flood_high = flood,
                                         precincts = layer("precincts"),
                                         gully_hazard = layer("gully_hazard"),
                                         peacocke_height = layer("peacocke_height"),
                                         amenity_protection = apa))
  list(zoning = z[, "zone"], parcels = land, roads = roads, layers = layers,
       centrelines = layer("centrelines"))
}
