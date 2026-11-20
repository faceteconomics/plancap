# A small cadastre where every answer is obvious by construction, carried over
# from capacityengine's fixtures. Road along y = -20..0; parcels north of it:
#   P7 x 0-20, P1 x 20-40, P2 x 40-60, P4 x 60-80, P5 x 80-100 (all y 0-30);
#   P6 x 20-40, y 40-70 (no road contact); a reserve north of P6 (y 70-90).
NZTM <- 2193

rect <- function(x0, y0, x1, y1) {
  sf::st_polygon(list(matrix(c(x0, y0, x1, y0, x1, y1, x0, y1, x0, y0), ncol = 2, byrow = TRUE)))
}

fixture_parcels <- function() {
  sf::st_sf(
    parcel_id = c("P7", "P1", "P2", "P4", "P5", "P6"),
    title_id = c("T7", "T1", "T2", "T45", "T45", "T6"),
    geometry = sf::st_sfc(rect(0, 0, 20, 30), rect(20, 0, 40, 30), rect(40, 0, 60, 30),
                          rect(60, 0, 80, 30), rect(80, 0, 100, 30), rect(20, 40, 40, 70),
                          crs = NZTM))
}

fixture_road <- function() {
  sf::st_sf(road_id = "R1", geometry = sf::st_sfc(rect(-200, -20, 300, 0), crs = NZTM))
}

# Adds a north-south road west of P7, making P7 a corner site.
fixture_road_cross <- function() {
  sf::st_sf(road_id = c("R1", "R2"),
            geometry = sf::st_sfc(rect(-200, -20, 300, 0), rect(-20, 0, 0, 300), crs = NZTM))
}

fixture_rulebook <- function() {
  rulebook("Fixture plan") |>
    add_zone(zone("A", method = "volumetric", height = height_limit(8, source = "A1")),
             zone("B", method = "volumetric", height = height_limit(11, source = "B1")),
             zone("OS", "Open space", method = "none", source = "OS")) |>
    set_zone_families(OPEN_SPACE = "OS", RES = c("A", "B"))
}

# Zone A west of x = split, zone B east of it; open space north of y = 70.
fixture_zoning <- function(split = 40) {
  sf::st_sf(zone = c("A", "B", "OS"),
            geometry = sf::st_sfc(rect(-200, -100, split, 70), rect(split, -100, 300, 70),
                                  rect(-200, 70, 300, 300), crs = NZTM))
}

fixture_scenario <- function(zoning = fixture_zoning(), ...) {
  scenario("Fixture", fixture_rulebook(), parcels = fixture_parcels(),
           roads = fixture_road(), zoning = zoning, ...)
}

seg_of <- function(x, site) x[x$site_id == site, , drop = FALSE]
