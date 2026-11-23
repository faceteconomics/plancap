# Prepare the Hamilton extract for plancap: zone codes the rulebook maps, and
# parcels split into land and roads. Sourced by run.R and the vignette's
# source (vignettes/hamilton.Rmd.orig).

hamilton_inputs <- function(dir = "data-raw/cache/hamilton") {
  z <- sf::st_read(file.path(dir, "zoning.gpkg"), quiet = TRUE)
  # The Industrial Amenity Protection Area is an overlay stored with the zones,
  # and the Transport Corridor Zone is one polygon under every other zone (it
  # covers the whole extract); roads come from the road parcels instead.
  z <- z[!grepl("Amenity Protection|Transport Corridor", z$Zone_Description), ]
  d <- z$Zone_Description
  z$zone <- ifelse(grepl("General Residential", d), "General Residential",
            ifelse(grepl("Medium Density Residential", d), "Medium Density Residential",
            ifelse(grepl("High Density Residential", d), "High Density Residential",
            ifelse(grepl("Business 6", d), "Business 6",
            ifelse(grepl("Business 2", d), "Business 2",
            ifelse(grepl("Community Facilities", d), "Community Facilities",
            ifelse(grepl("Major Facilities", d), "Major Facilities",
            ifelse(grepl("Open Space", d), "Open Space",
            ifelse(grepl("^Industrial", d), "Industrial",
            ifelse(grepl("Transport Corridor", d), "Transport Corridor", NA))))))))))
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
  list(zoning = z[, "zone"], parcels = land, roads = roads)
}
