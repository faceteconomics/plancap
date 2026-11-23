#' A 3D view of capacity
#'
#' An interactive map of a capacity result, each site raised to the height
#' its envelope reaches and coloured by its capacity per hectare. With
#' `footprints = TRUE` each storey's footprint is drawn at its own level
#' instead, so the setbacks and planes show as the stepped form they make
#' (practical for a few thousand sites). Hover a site for its figures. Needs
#' the mapgl package; the basemap (OpenFreeMap's Positron, keyless) is fetched
#' when the map is viewed.
#'
#' @param cap A capacity result from [estimate_capacity()].
#' @param measure The measure to colour by, per hectare of land.
#' @param footprints Whether to draw each storey's footprint rather than the
#'   site raised to its height.
#' @param style A MapLibre style; default OpenFreeMap's Positron.
#' @param pitch,bearing The view angle.
#' @return An htmlwidget (a mapgl map).
#' @export
#' @examplesIf interactive() && rlang::is_installed("mapgl")
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' view_capacity_3d(estimate_capacity(sc), footprints = TRUE)
view_capacity_3d <- function(cap, measure = "floor_area", footprints = FALSE, style = NULL,
                             pitch = 55, bearing = -20) {
  check_capacity_object(cap)
  rlang::check_installed("mapgl", reason = "for the 3D view.")
  s <- cap$sites
  s$value <- ifelse(s$area > 0, s[[measure]] / s$area * 10000, NA)
  fmt <- measure_formatter(measure)
  s$label <- sprintf("<b>%s</b> %s<br>%s floor area, %s dwellings<br>%s storeys, %s m; limited by %s",
                     s$site_id, s$zone_key %|NA|% "no zone", label_area(s$floor_area), label_count(s$dwellings),
                     s$storeys, formatC(s$height %|NA|% 0, format = "f", digits = 1),
                     s$envelope_binding %|NA|% "nothing")
  if (footprints) {
    x <- cap$inputs
    if (is.null(x)) cli::cli_abort("This capacity result does not carry its scenario; rerun {.fn estimate_capacity}.")
    ids <- s$site_id[s$floor_area > 0]
    opts <- cap$options[intersect(names(cap$options), c("variant_choice", "max_storeys"))]
    env <- do.call(build_envelopes, c(list(x, include_density = TRUE, keep_geometry = TRUE, .only = ids), opts))
    g <- env$geometry
    st <- cap$stack
    k <- match(paste(g$site_id, g$storey), paste(st$site_id, st$storey))
    g <- g[!is.na(k), ]
    k <- k[!is.na(k)]
    g$base <- st$floor_level[k]
    g$top <- st$ceiling_level[k]
    i <- match(g$site_id, s$site_id)
    g$value <- s$value[i]
    g$label <- s$label[i]
    d <- g
  } else {
    d <- s[s$floor_area > 0, ]
    d$base <- 0
    d$top <- d$height %|NA|% 0
  }
  d <- sf::st_transform(d[, c("value", "label", "base", "top")], 4326)
  rng <- stats::quantile(d$value, c(0.02, 0.98), na.rm = TRUE)
  if (!all(is.finite(rng)) || rng[1] == rng[2]) rng <- range(d$value, na.rm = TRUE) + c(0, 1)
  cols <- capacity_palette("sequential", 7)
  vals <- seq(rng[[1]], rng[[2]], length.out = 7)
  m <- mapgl::maplibre(style = style %||% mapgl::openfreemap_style("positron"), bounds = d, pitch = pitch, bearing = bearing,
                        projection = "mercator")
  m <- mapgl::add_fill_extrusion_layer(
    m, id = "capacity", source = d,
    fill_extrusion_color = mapgl::interpolate(column = "value", values = vals, stops = cols, na_color = "#c3c2b7"),
    fill_extrusion_height = mapgl::get_column("top"),
    fill_extrusion_base = mapgl::get_column("base"),
    fill_extrusion_opacity = 0.9, tooltip = "label")
  mapgl::add_legend(m, paste(measure_label(measure), "per hectare"), values = fmt(rng), colors = cols,
                    type = "continuous", position = "bottom-left")
}

# A basemap layer for the static maps, fetched with maptiles: `basemap` is
# TRUE (Esri's World Gray Canvas, which needs no key) or a maptiles provider
# name.
basemap_layer <- function(d, basemap = TRUE) {
  rlang::check_installed(c("maptiles", "tidyterra"), reason = "to draw a basemap.")
  provider <- if (isTRUE(basemap)) "Esri.WorldGrayCanvas" else basemap
  tiles <- maptiles::get_tiles(sf::st_transform(sf::st_as_sfc(sf::st_bbox(d)), 3857), provider = provider,
                               crop = TRUE, project = FALSE)
  list(tidyterra::geom_spatraster_rgb(data = tiles, maxcell = 2e6))
}

basemap_credit <- function(basemap) {
  if (isTRUE(basemap)) "Basemap: Esri, World Gray Canvas." else paste0("Basemap: ", basemap, ".")
}
