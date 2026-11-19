#' Exampleton: a synthetic town for examples and tests
#'
#' Exampleton is a made-up town of about 1,500 parcels, built by the script in
#' `data-raw/exampleton.R` so that every rule type plancap handles has
#' something to act on. It is placed in the sea about 250 km east of New
#' Zealand's North Island, in New Zealand Transverse Mercator (EPSG:2193), so
#' it cannot be mistaken for a real place.
#'
#' What it contains, and what each part is there to exercise:
#'
#' | Layer | Geometry | Exercises |
#' |---|---|---|
#' | `parcels` | polygon | Land lots, road parcels and reserves in one layer, as a national cadastre supplies them (`parcel_type`). Corner lots, rear (battle-axe) lots with access legs, through lots, a large amalgamated site, and lots that share a `title_id` |
#' | `road_centrelines` | line | Street names and road reserve widths (`width_m`); Main Street is wider |
#' | `zoning` | polygon | Seven zones (`zone`); one block is split between two zones, so some lots straddle a zone boundary |
#' | `height_areas` | polygon | Mapped height limits (`max_height_m`) over the centre and its frame |
#' | `flood_hazard` | polygon | An exclusion along the river |
#' | `heritage` | polygon | A flag-only overlay on a few centre lots |
#' | `precincts` | polygon | One precinct with two sub-precincts (`sub_precinct`) |
#' | `water` | line | A river through the southern reserve, for riparian setbacks |
#' | `transit` | point | A station, for distance-band rules |
#' | `trees` | point | Trees with trunk diameter (`dbh_m`) and a `protected` flag |
#' | `buildings` | polygon | Existing buildings with `storeys`, for net-of-existing capacity |
#'
#' A ground surface is supplied separately as a 5 m raster; see
#' [exampleton_dem()].
#'
#' @return `exampleton()` returns a named list of `sf` data frames, one per
#'   layer. `exampleton_layer()` returns one `sf` data frame.
#' @seealso [exampleton_dem()], [exampleton_path()]
#' @export
#' @examples
#' town <- exampleton()
#' names(town)
#' table(town$parcels$parcel_type)
#'
#' zones <- exampleton_layer("zoning")
#' zones$zone
exampleton <- function() {
  layers <- exampleton_layers()
  out <- lapply(layers, exampleton_layer)
  names(out) <- layers
  out
}

#' @rdname exampleton
#' @param layer Name of one layer. See `exampleton_layers()`.
#' @export
exampleton_layer <- function(layer) {
  layer <- rlang::arg_match(layer, exampleton_layers())
  sf::st_read(exampleton_path("gpkg"), layer = layer, quiet = TRUE,
              stringsAsFactors = FALSE)
}

#' @rdname exampleton
#' @export
exampleton_layers <- function() {
  c("parcels", "road_centrelines", "zoning", "height_areas", "flood_hazard",
    "heritage", "precincts", "water", "transit", "trees", "buildings")
}

#' Exampleton ground surface
#'
#' A 5 m digital elevation model of [exampleton()]: a gentle rise to the north,
#' a hill in the north-east steep enough to trigger slope rules (above 15 per
#' cent), and a shallow river valley in the south.
#'
#' @return A `terra::SpatRaster` of ground level in metres.
#' @export
#' @examplesIf rlang::is_installed("terra")
#' dem <- exampleton_dem()
#' dem
exampleton_dem <- function() {
  rlang::check_installed("terra", reason = "to read the Exampleton ground surface.")
  terra::rast(exampleton_path("dem"))
}

#' Path to an Exampleton file
#'
#' @param file `"gpkg"` for the vector layers, `"dem"` for the ground surface.
#' @return The full path to the file installed with the package.
#' @export
#' @examples
#' exampleton_path("gpkg")
exampleton_path <- function(file = c("gpkg", "dem")) {
  file <- rlang::arg_match(file)
  name <- switch(file, gpkg = "exampleton.gpkg", dem = "exampleton_dem.tif")
  path <- system.file("extdata", name, package = "plancap")
  if (!nzchar(path)) {
    cli::cli_abort("Exampleton file {.file {name}} is missing from the installed package.")
  }
  path
}
