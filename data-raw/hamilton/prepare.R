# Prepare a Hamilton extract for plancap: zone codes the rulebook maps,
# parcels split into land and roads, the overlay layers and the road centre
# lines. Sourced by run.R and the vignette's source (vignettes/hamilton.Rmd.orig).

hamilton_inputs <- function(dir = "data-raw/cache/hamilton") {
  z <- sf::st_read(file.path(dir, "zoning.gpkg"), quiet = TRUE)
  # The Industrial Amenity Protection Area is an overlay stored with the zones,
  # and the Transport Corridor Zone is one polygon under every other zone (it
  # covers the whole extract); roads come from the road parcels instead.
  z <- z[!is.na(z$Zone_Description) & !grepl("Amenity Protection|Transport Corridor", z$Zone_Description), ]
  # The council's polygons overlap in slivers (Peacocke); the first keeps each overlap.
  z <- suppressWarnings(sf::st_collection_extract(sf::st_difference(z), "POLYGON"))
  d <- z$Zone_Description
  # First match wins: Peacocke's zone names contain the general ones.
  codes <- c("Peacocke Medium Density Residential" = "Peacocke Medium Density Residential",
             "Large Lot Residential" = "Large Lot Residential",
             "General Residential" = "General Residential",
             "Medium Density Residential" = "Medium Density Residential",
             "High Density Residential" = "High Density Residential",
             "Business 6" = "Business 6",
             "Business 2" = "Business 2",
             "Community Facilities" = "Community Facilities",
             "Major Facilities" = "Major Facilities",
             "^Open Space" = "Open Space",
             "^Industrial" = "Industrial")
  z$zone <- NA_character_
  for (k in names(codes)) z$zone[is.na(z$zone) & grepl(k, d)] <- codes[[k]]
  # Zones the rulebook does not yet hold keep their description (H2 adds them).
  z$zone[is.na(z$zone)] <- d[is.na(z$zone)]
  # Business 6's height and floor area ratio depend on the residential zone it
  # adjoins (6.4.1, 6.4.4): code each centre polygon by its neighbour, Medium
  # Density where it touches any.
  b6 <- which(z$zone %in% "Business 6")
  mrz <- z[z$zone %in% "Medium Density Residential", ]
  near_mrz <- lengths(sf::st_is_within_distance(z[b6, ], mrz, 30)) > 0
  z$zone[b6] <- ifelse(near_mrz, "Business 6 (Medium Density Residential)", "Business 6 (General Residential)")
  p <- sf::st_read(file.path(dir, "parcels.gpkg"), quiet = TRUE)
  p$parcel_id <- as.character(p$id)
  land <- p[!p$parcel_intent %in% c("Road", "Hydro", "Railway"), "parcel_id"]
  roads <- p[p$parcel_intent %in% "Road", 0]
  layer <- function(f) {
    f <- file.path(dir, paste0(f, ".gpkg"))
    if (file.exists(f)) sf::st_read(f, quiet = TRUE) else NULL
  }
  layers <- Filter(Negate(is.null), list(infrastructure_capacity = layer("infrastructure_capacity"),
                                         precincts = layer("precincts"),
                                         gully_hazard = layer("gully_hazard")))
  list(zoning = z[, "zone"], parcels = land, roads = roads, layers = layers,
       centrelines = layer("centrelines"))
}
