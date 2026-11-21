#' Summarise capacity by zone, height, size, location or binding constraint
#'
#' One function for every breakdown of a capacity result. `by` names what to
#' group by; `measures` names what to report. Every site is counted once, in
#' one group, so groups always add up to the total.
#'
#' @section Grouping (`by`):
#' Any column of `cap$sites` (such as `zone_key`, `zone_code`, `method`,
#' `path`, `variant`, `flag`, `envelope_binding`, `dwelling_binding`), and:
#' - `"zone"`: the zone key;
#' - `"storeys"`: the number of storeys the envelope reaches;
#' - `"height_band"`: the envelope's height, in bands (`breaks$height`);
#' - `"site_size_band"`: site area, in bands (`breaks$site_size`);
#' - `"far_band"`: the floor area ratio achieved, in bands (`breaks$far`);
#' - `"binding"`: the constraint that limits dwellings (`dwelling_binding`);
#' - `"area"`: the polygons given as `areas`, labelled by `area_id`; each site
#'   is assigned to the area that covers most of it ("(outside)" where none
#'   does);
#' - `"grid"`: square cells of `grid` metres, by each site's point on surface;
#' - `"storey"`: floor area **by storey level** (where capacity sits
#'   vertically), from the storey stack: a site counts in every storey it
#'   reaches, and only floor area measures apply.
#'
#' @section Measures:
#' `sites`, `land_area`, `footprint`, `floor_area`, `residential_floor_area`,
#' `business_floor_area`, `dwellings`, `minor_dwellings`, `floor_area_mean`
#' and `floor_area_median` (per site), `dwellings_mean`, `far` (floor area
#' over land area), `floor_area_per_ha` and `dwellings_per_ha` (of land),
#' `floor_area_share` and `dwellings_share` (of the total), and the
#' `*_with_bonus` columns. `"gfa"` is accepted for `floor_area`.
#'
#' @param cap A capacity result from [estimate_capacity()].
#' @param by Character vector of groupings (see the section); `NULL` for one
#'   total row.
#' @param measures Character vector of measures.
#' @param areas Polygons for `by = "area"`.
#' @param area_id Column of `areas` naming each area.
#' @param grid Cell size (m) for `by = "grid"`.
#' @param breaks Named list overriding the band breaks: `height` (m),
#'   `site_size` (m2) and `far`.
#' @param include_zero Whether sites with no capacity (open space, unzoned)
#'   are counted. They are by default, so land area reconciles.
#' @return A data frame of class `plancap_summary`, one row per group; an
#'   `sf` data frame of the areas or cells for a spatial grouping.
#' @seealso [capacity_table()] to format it; [summary.plancap_capacity()]
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' cap <- estimate_capacity(sc)
#' summarise_capacity(cap)
#' summarise_capacity(cap, by = c("zone", "height_band"), measures = c("sites", "floor_area"))
#' summarise_capacity(cap, by = "storey")
summarise_capacity <- function(cap, by = "zone", measures = default_measures(),
                               areas = NULL, area_id = NULL, grid = NULL, breaks = list(),
                               include_zero = TRUE) {
  check_capacity_object(cap)
  measures <- sub("^gfa$", "floor_area", measures)
  bad <- setdiff(measures, all_measures())
  if (length(bad)) cli::cli_abort(c("Unknown measure{?s}: {.val {bad}}.",
                                    "i" = "Measures: {.val {all_measures()}}."))
  if ("storey" %in% by) return(summarise_by_storey(cap, setdiff(by, "storey"), measures, breaks))
  d <- site_frame(cap, by, areas, area_id, grid, breaks)
  if (!include_zero) d <- d[d$floor_area > 0 | d$dwellings > 0, , drop = FALSE]
  keys <- by_columns(by)
  out <- group_measures(d, keys, measures)
  spatial <- intersect(keys, c("area", "grid"))
  if (length(spatial) == 1 && length(keys) == 1) {
    g <- attr(d, "unit_geometry")
    if (!is.null(g)) {
      geom <- g$geometry[match(out[[spatial]], g$id)]
      out <- sf::st_sf(out, geometry = geom)
    }
  }
  structure_summary(out, keys, measures, cap)
}

#' @rdname summarise_capacity
#' @export
default_measures <- function() c("sites", "land_area", "floor_area", "dwellings", "far", "floor_area_share")

all_measures <- function() {
  c("sites", "land_area", "footprint", "floor_area", "residential_floor_area", "business_floor_area",
    "dwellings", "minor_dwellings", "floor_area_mean", "floor_area_median", "dwellings_mean", "far",
    "floor_area_per_ha", "dwellings_per_ha", "floor_area_share", "dwellings_share",
    "floor_area_with_bonus", "dwellings_with_bonus")
}

check_capacity_object <- function(cap, arg = rlang::caller_arg(cap), call = rlang::caller_env()) {
  if (!inherits(cap, "plancap_capacity")) {
    cli::cli_abort("{.arg {arg}} must be a result of {.fn estimate_capacity}.", call = call)
  }
}

band_defaults <- function() {
  list(height = c(0, 9, 12, 16, 22, 30, 45, Inf),
       site_size = c(0, 300, 600, 1000, 2000, 10000, Inf),
       far = c(0, 0.5, 1, 2, 4, 8, Inf))
}

# Bands as ordered factors with readable labels: "9-12 m", "45 m+".
make_band <- function(x, br, unit = "") {
  lab <- vapply(seq_len(length(br) - 1), function(i) {
    lo <- format(br[i], big.mark = ",", trim = TRUE)
    if (is.infinite(br[i + 1])) paste0(lo, unit, "+") else
      paste0(lo, "-", format(br[i + 1], big.mark = ",", trim = TRUE), unit)
  }, "")
  cut(x, br, labels = lab, right = FALSE, include.lowest = TRUE, ordered_result = TRUE)
}

by_columns <- function(by) {
  if (is.null(by)) return(character())
  out <- by
  out[out == "zone"] <- "zone_key"
  out[out == "binding"] <- "dwelling_binding"
  out
}

# One row per site with every grouping column the request needs.
site_frame <- function(cap, by, areas, area_id, grid, breaks) {
  s <- cap$sites
  d <- sf::st_drop_geometry(s)
  # Land area under its own name, so a grouping called "area" cannot replace it.
  d$.land <- d$area
  br <- utils::modifyList(band_defaults(), breaks)
  if ("height_band" %in% by) d$height_band <- make_band(ifelse(is.na(d$height), 0, d$height), br$height, " m")
  if ("site_size_band" %in% by) d$site_size_band <- make_band(d$area, br$site_size, " m2")
  if ("far_band" %in% by) d$far_band <- make_band(ifelse(d$area > 0, d$floor_area / d$area, 0), br$far)
  if ("area" %in% by) {
    if (is.null(areas) || is.null(area_id)) cli::cli_abort("{.code by = \"area\"} needs {.arg areas} and {.arg area_id}.")
    if (!area_id %in% names(areas)) cli::cli_abort("{.arg areas} has no {.field {area_id}} column.")
    if (sf::st_crs(areas) != sf::st_crs(s)) areas <- sf::st_transform(areas, sf::st_crs(s))
    ag <- geos::geos_make_valid(as_geos(areas))
    ov <- overlap_table(as_geos(s), ag, min_area = 0)
    ov <- ov[order(ov$site, -ov$area), ]
    ov <- ov[!duplicated(ov$site), ]
    ids <- as.character(areas[[area_id]])
    d$area <- "(outside)"
    d$area[ov$site] <- ids[ov$feature]
    attr(d, "unit_geometry") <- list(id = ids, geometry = sf::st_geometry(areas))
  }
  if ("grid" %in% by) {
    if (is.null(grid)) cli::cli_abort("{.code by = \"grid\"} needs a cell size, {.arg grid}.")
    pt <- geos::geos_point_on_surface(as_geos(s))
    gx <- floor(geos::geos_x(pt) / grid)
    gy <- floor(geos::geos_y(pt) / grid)
    d$grid <- paste0(gx, "_", gy)
    u <- unique(d$grid)
    ux <- as.numeric(sub("_.*", "", u))
    uy <- as.numeric(sub(".*_", "", u))
    cells <- sf::st_as_sfc(wk::rct(ux * grid, uy * grid, (ux + 1) * grid, (uy + 1) * grid))
    sf::st_crs(cells) <- sf::st_crs(s)
    attr(d, "unit_geometry") <- list(id = u, geometry = cells)
  }
  keys <- by_columns(by)
  miss <- setdiff(keys, names(d))
  if (length(miss)) {
    cli::cli_abort(c("Cannot group by {.val {miss}}.",
                     "i" = "Use a column of {.code cap$sites} or one of {.val {c('zone', 'storeys', 'height_band', 'site_size_band', 'far_band', 'binding', 'area', 'grid', 'storey')}}."))
  }
  for (k in keys) {
    if (is.character(d[[k]])) d[[k]][is.na(d[[k]])] <- "(none)"
  }
  d
}

group_measures <- function(d, keys, measures) {
  grp <- if (length(keys)) interaction(d[keys], drop = TRUE, lex.order = TRUE) else factor(rep("all", nrow(d)))
  idx <- split(seq_len(nrow(d)), grp)
  first <- vapply(idx, `[`, 1L, 1L)
  out <- d[first, keys, drop = FALSE]
  rownames(out) <- NULL
  tot_fa <- sum(d$floor_area)
  tot_dw <- sum(d$dwellings)
  sm <- function(col) vapply(idx, function(i) sum(d[[col]][i], na.rm = TRUE), 0)
  for (m in measures) {
    out[[m]] <- switch(m,
      sites = lengths(idx),
      land_area = sm(".land"),
      floor_area_mean = vapply(idx, function(i) mean(d$floor_area[i]), 0),
      floor_area_median = vapply(idx, function(i) stats::median(d$floor_area[i]), 0),
      dwellings_mean = vapply(idx, function(i) mean(d$dwellings[i]), 0),
      far = sm("floor_area") / pmax(sm(".land"), 1e-9),
      floor_area_per_ha = sm("floor_area") / pmax(sm(".land"), 1e-9) * 10000,
      dwellings_per_ha = sm("dwellings") / pmax(sm(".land"), 1e-9) * 10000,
      floor_area_share = if (tot_fa > 0) sm("floor_area") / tot_fa else 0,
      dwellings_share = if (tot_dw > 0) sm("dwellings") / tot_dw else 0,
      sm(m))
  }
  if (length(keys)) out <- out[do.call(order, unname(as.list(out[keys]))), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Floor area by storey level, from the stack.
summarise_by_storey <- function(cap, by, measures, breaks) {
  ok <- c("sites", "floor_area", "residential_floor_area", "business_floor_area", "floor_area_share")
  measures <- intersect(measures, ok)
  if (!length(measures)) measures <- c("sites", "floor_area")
  st <- cap$stack
  d <- site_frame(cap, by, NULL, NULL, NULL, breaks)
  keys <- by_columns(by)
  i <- match(st$site_id, d$site_id)
  x <- data.frame(storey = st$storey, floor_area = st$enabled_area,
                  residential_floor_area = st$residential_area, business_floor_area = st$business_area)
  for (k in keys) x[[k]] <- d[[k]][i]
  x$dwellings <- 0
  x$.land <- 0
  out <- group_measures(x, c(keys, "storey"), measures)
  structure_summary(out, c(keys, "storey"), measures, cap)
}

structure_summary <- function(out, keys, measures, cap) {
  attr(out, "by") <- keys
  attr(out, "measures") <- measures
  attr(out, "scenario") <- cap$scenario
  attr(out, "conversion") <- cap$conversion
  class(out) <- unique(c("plancap_summary", class(out)))
  out
}

#' @export
print.plancap_summary <- function(x, ...) {
  cli::cli_text("{.strong <plancap summary>} {attr(x, 'scenario')}, by \\
                 {if (length(attr(x, 'by'))) paste(attr(x, 'by'), collapse = ', ') else 'total'}: \\
                 {nrow(x)} row{?s}")
  df <- if (inherits(x, "sf")) sf::st_drop_geometry(x) else x
  df <- as.data.frame(unclass(df), stringsAsFactors = FALSE)
  print(format_summary(df), row.names = FALSE, right = TRUE)
  invisible(x)
}

# Numbers made readable: areas and counts with thousands separators, ratios
# to two places, shares as percentages.
format_summary <- function(df) {
  for (m in names(df)) {
    v <- df[[m]]
    if (!is.numeric(v) || m %in% c("value", "storey", "storeys")) next
    df[[m]] <- if (grepl("share$", m)) sprintf("%.1f%%", 100 * v)
      else if (m %in% c("far")) formatC(v, format = "f", digits = 2)
      else if (grepl("_mean$|_median$|_per_ha$", m)) formatC(v, format = "f", digits = 1, big.mark = ",")
      else formatC(round(v), format = "d", big.mark = ",")
  }
  df
}

#' Summarise a capacity result
#'
#' The headline (sites, land, floor area, dwellings), capacity by zone, and a
#' tally of flags and binding constraints.
#'
#' @param object A capacity result from [estimate_capacity()].
#' @param ... Unused.
#' @return A `plancap_capacity_summary` list: `headline`, `by_zone`, `flags`
#'   and `binding`, printed readably.
#' @export
summary.plancap_capacity <- function(object, ...) {
  s <- sf::st_drop_geometry(object$sites)
  headline <- data.frame(sites = nrow(s), land_area = sum(s$area), floor_area = sum(s$floor_area),
                         residential_floor_area = sum(s$residential_floor_area),
                         business_floor_area = sum(s$business_floor_area), dwellings = sum(s$dwellings),
                         minor_dwellings = sum(s$minor_dwellings))
  structure(list(headline = headline,
                 by_zone = summarise_capacity(object, by = "zone"),
                 flags = as.data.frame(table(flag = s$flag), stringsAsFactors = FALSE),
                 binding = as.data.frame(table(binding = s$dwelling_binding), stringsAsFactors = FALSE),
                 scenario = object$scenario, conversion = object$conversion),
            class = "plancap_capacity_summary")
}

#' @export
print.plancap_capacity_summary <- function(x, ...) {
  h <- x$headline
  f <- function(v) format(round(v), big.mark = ",")
  cli::cli_h2("Capacity: {x$scenario}")
  cli::cli_text("{f(h$sites)} sites on {format(round(h$land_area / 10000, 1), big.mark = ",")} ha: {f(h$floor_area)} m2 of floor area \\
                 ({f(h$residential_floor_area)} m2 residential, {f(h$business_floor_area)} m2 business), \\
                 {f(h$dwellings)} dwellings and {f(h$minor_dwellings)} minor dwellings.")
  cli::cli_text("{.emph {conversion_note(x$conversion)}}")
  cli::cli_h3("By zone")
  print(format_summary(as.data.frame(unclass(x$by_zone))), row.names = FALSE, right = TRUE)
  cli::cli_h3("Flags")
  cli::cli_text(paste0(x$flags$flag, " ", f(x$flags$Freq), collapse = ", "))
  b <- x$binding[order(-x$binding$Freq), ]
  if (nrow(b)) {
    cli::cli_h3("What limits dwellings")
    cli::cli_text(paste0(b$binding, " ", f(b$Freq), collapse = ", "))
  }
  invisible(x)
}

conversion_note <- function(conv) {
  size <- conv$dwelling_size %||% round(sum(vapply(conv$unit_mix, function(u) u$size * u$share, 0)))
  sprintf("Plan-enabled, gross, blank-slate capacity; dwellings at %s m2 and %s%% efficiency.",
          size, round(100 * (conv$efficiency %||% 1)))
}

#' A formatted capacity table
#'
#' Formats a summary as a `gt` table, with readable numbers, a title and a
#' source note stating what the figures are. Without the gt package, returns
#' the formatted data frame.
#'
#' @param x A summary from [summarise_capacity()] (or a capacity result,
#'   summarised by zone).
#' @param title Optional title; default names the scenario.
#' @param ... Passed to [summarise_capacity()] when `x` is a capacity result.
#' @return A `gt_tbl`, or a data frame.
#' @export
#' @examples
#' town <- exampleton()
#' sc <- scenario("Operative", rulebook_example("exampleton"),
#'                parcels = town$parcels[town$parcels$parcel_type == "land", ],
#'                roads = town$parcels[town$parcels$parcel_type == "road", ],
#'                zoning = town$zoning, layers = town[c("height_areas", "transit")])
#' capacity_table(estimate_capacity(sc))
capacity_table <- function(x, title = NULL, ...) {
  if (inherits(x, "plancap_capacity")) x <- summarise_capacity(x, ...)
  if (!inherits(x, "plancap_summary")) cli::cli_abort("{.arg x} must be a capacity summary or result.")
  df <- if (inherits(x, "sf")) sf::st_drop_geometry(x) else x
  df <- as.data.frame(unclass(df), stringsAsFactors = FALSE)
  for (k in attr(x, "by")) if (is.factor(df[[k]])) df[[k]] <- as.character(df[[k]])
  title <- title %||% paste("Plan-enabled capacity:", attr(x, "scenario"))
  note <- conversion_note(attr(x, "conversion"))
  if (!requireNamespace("gt", quietly = TRUE)) {
    cli::cli_inform("Install {.pkg gt} for a formatted table; returning a data frame.")
    return(format_summary(df))
  }
  labels <- c(sites = "Sites", land_area = "Land (m\u00b2)", footprint = "Footprint (m\u00b2)",
              floor_area = "Floor area (m\u00b2)", residential_floor_area = "Residential (m\u00b2)",
              business_floor_area = "Business (m\u00b2)", dwellings = "Dwellings",
              minor_dwellings = "Minor dwellings", floor_area_mean = "Mean floor area (m\u00b2)",
              floor_area_median = "Median floor area (m\u00b2)", dwellings_mean = "Mean dwellings",
              far = "Floor area ratio", floor_area_per_ha = "Floor area per ha (m\u00b2)",
              dwellings_per_ha = "Dwellings per ha", floor_area_share = "Share of floor area",
              dwellings_share = "Share of dwellings", zone_key = "Zone", height_band = "Height",
              site_size_band = "Site area", far_band = "Floor area ratio", storeys = "Storeys",
              storey = "Storey", dwelling_binding = "Limited by", area = "Area")
  tb <- gt::gt(df)
  tb <- gt::tab_header(tb, title = title)
  tb <- gt::tab_source_note(tb, note)
  cols <- names(df)
  lab <- labels[intersect(cols, names(labels))]
  if (length(lab)) tb <- gt::cols_label(tb, .list = as.list(lab))
  shares <- grep("share$", cols, value = TRUE)
  ints <- intersect(cols, c("sites", "land_area", "footprint", "floor_area", "residential_floor_area",
                            "business_floor_area", "dwellings", "minor_dwellings", "floor_area_with_bonus",
                            "dwellings_with_bonus"))
  dec1 <- grep("_mean$|_median$|_per_ha$", cols, value = TRUE)
  if (length(ints)) tb <- gt::fmt_number(tb, columns = ints, decimals = 0)
  if (length(dec1)) tb <- gt::fmt_number(tb, columns = dec1, decimals = 1)
  if ("far" %in% cols) tb <- gt::fmt_number(tb, columns = "far", decimals = 2)
  if (length(shares)) tb <- gt::fmt_percent(tb, columns = shares, decimals = 1)
  num <- cols[vapply(df, is.numeric, TRUE)]
  if (length(num) && !"storey" %in% attr(x, "by")) {
    sums <- intersect(c(ints, shares), num)
    if (length(sums)) {
      tb <- gt::grand_summary_rows(tb, columns = sums, fns = list(Total = ~ sum(., na.rm = TRUE)),
                                   fmt = ~ gt::fmt_number(., decimals = 0))
    }
  }
  tb
}
