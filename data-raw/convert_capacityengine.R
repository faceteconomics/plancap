# Convert capacityengine plan bundles to plancap rulebooks.
#
# Run from the package root:
#   Rscript data-raw/convert_capacityengine.R [path/to/capacityengine]
#
# Writes inst/rulebooks/<name>.yaml and data-raw/conversion/<name>.md, a
# report of every field the conversion could not carry across. Nothing is
# dropped silently: a field with no plancap equivalent is listed in the report
# and, where it is a rule, added to the rulebook's unmodelled_rules.
#
# Mapping notes:
# * capacityengine's NZ zone keys stay as zone keys; its alias_map becomes the
#   zone_map. Unmodelled zones become zones with method "none", keyed by
#   their code, so neighbour-dependent rules can still see them.
# * yards, hirb and upper_level_setback become setbacks of kind yard, plane
#   and upper_level. An override's yards replace only the zone's yards
#   (replaces_setbacks), as in capacityengine.
# * southern_boundary_only becomes the condition facing: [270, 90]: the
#   outward normal points north (capacityengine on_southern_boundary_of_neighbour).
# * Precinct areas match on a precinct_key column holding the normalised
#   precinct name (lower case, non-alphanumerics to "_"), which is how
#   capacityengine matches them.
# * conversion: dwellings = floor area / (size * (1 + circulation + storage)),
#   so efficiency = 1 / (1 + circulation + storage).

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))

args <- commandArgs(trailingOnly = TRUE)
ce <- if (length(args)) args[1] else "../capacityengine"
bundles <- c(
  wellington = file.path(ce, "inst/plans/wellington/wcc-dp-2024.yaml"),
  christchurch = file.path(ce, "inst/plans/christchurch/ccc-dp-2025.yaml"),
  auckland = file.path(ce, "inst/plans/auckland/aup-oip-2025.yaml")
)
if (length(args) > 1) bundles <- bundles[args[-1]]

`%||%` <- function(x, y) if (is.null(x)) y else x
plan_names <- c(wellington = "Wellington City District Plan 2024",
                christchurch = "Christchurch District Plan",
                auckland = "Auckland Unitary Plan (Operative in part)")
compact <- function(x) x[!vapply(x, is.null, logical(1))]

# ---- Report of what could not be carried across ------------------------------

dropped <- new.env()
drop <- function(where, field, value = NULL) {
  key <- paste0(where, " :: ", field)
  dropped[[key]] <- if (is.null(value)) "" else substr(paste(deparse(value), collapse = " "), 1, 120)
}

# ---- Conditions --------------------------------------------------------------

conv_when <- function(r, where) {
  w <- compact(list(
    min_site_area = r[["min_site_area_m2"]], max_site_area = r[["max_site_area_m2"]],
    rear_sites = if (isFALSE(r[["applies_to_rear_sites"]])) "exclude",
    within_frontage = r[["from_frontage_max_m"]], beyond_frontage = r[["from_frontage_min_m"]],
    frontage_depth_share = r[["frontage_depth_share"]],
    adjacent_zones = r[["adjacent_zones"]], not_adjacent_zones = r[["except_adjacent_zones"]],
    facing = if (isTRUE(r[["southern_boundary_only"]])) c(270, 90)
  ))
  for (f in c("from_far_side_of_access", "far_side_max_m", "adjacency_token",
              "buffer_m", "buffer_by_zone")) {
    if (!is.null(r[[f]])) drop(where, f, r[[f]])
  }
  if (length(w)) w else NULL
}

# ---- Setbacks -----------------------------------------------------------------

conv_yard <- function(name, y, where) {
  w <- paste0(where, "/yards/", name)
  if (!is.null(y[["value_from"]])) {
    drop(w, "value_from (yard set from neighbours' existing setbacks; not representable)", y[["value_from"]])
    return(NULL)
  }
  if (!is.null(y[["max_value"]])) drop(w, "max_value", y[["max_value"]])
  compact(list(kind = "yard", name = name, distance = y[["value"]],
               from_storey = y[["above_storey"]], boundaries = as.character(unlist(y[["boundaries"]])),
               when = conv_when(y, w), variant = y[["variant"]],
               activity_status = y[["activity_status"]], source = y[["source"]]))
}

conv_plane <- function(h, where, i) {
  w <- paste0(where, "/hirb/", i)
  og <- h[["orientation_graded"]]
  ahs <- h[["above_height_setback"]]
  datum <- switch(h[["datum"]] %||% "segment_ground", segment_ground = NULL,
                  site_mean_ground = "site", fixed = { drop(w, "datum: fixed"); NULL })
  if (!is.null(h[["from_far_side_of_access"]])) drop(w, "from_far_side_of_access", TRUE)
  src <- h[["source"]]
  if (!is.null(ahs[["source"]])) src <- paste0(src %||% "", "; above ", ahs[["height_m"]], " m: ", ahs[["source"]])
  compact(list(
    kind = "plane", angle_deg = h[["angle_deg"]], start_height = h[["start_height_m"]],
    set_in = if (!is.null(h[["set_in_m"]]) && h[["set_in_m"]] > 0) h[["set_in_m"]],
    angle_by_orientation = if (!is.null(og)) og[c("north", "east", "south", "west")],
    vertical_above = h[["vertical_above_m"]],
    max_setback_above = if (!is.null(ahs)) c(list(height = ahs[["height_m"]]), ahs[c("north", "east", "south", "west")]),
    datum = datum,
    boundaries = as.character(unlist(h[["boundaries"]])),
    when = conv_when(h, w), variant = h[["variant"]], activity_status = h[["activity_status"]],
    source = src))
}

conv_uls <- function(u, where, i) {
  w <- paste0(where, "/upper_level_setback/", i)
  compact(list(kind = "upper_level", distance = u[["setback_m"]], above_height = u[["above_height_m"]],
               from_storey = u[["above_storey"]], boundaries = as.character(unlist(u[["boundaries"]])),
               when = conv_when(u, w), variant = u[["variant"]], source = u[["source"]]))
}

# ---- Ratios -------------------------------------------------------------------

conv_ratio <- function(v, where) {
  if (is.null(v)) return(NULL)
  if (is.numeric(v)) return(list(value = v))
  if (is.list(v) && is.null(names(v))) {
    ups <- vapply(v, function(b) b[["max_site_area_m2"]] %||% Inf, numeric(1))
    o <- order(ups)
    v <- v[o]
    ups <- ups[o]
    lows <- c(0, head(ups, -1))
    for (i in seq_along(v)) {
      if (!isTRUE(all.equal(v[[i]][["min_site_area_m2"]] %||% 0, lows[i]))) {
        drop(where, "band bounds not contiguous", v[[i]])
      }
    }
    return(list(bands = list(by = "site_area", bands = lapply(seq_along(v), function(i) compact(list(
      min = lows[i], max = if (is.finite(ups[i])) ups[i], value = v[[i]][["value"]]))))))
  }
  if (is.list(v) && !is.null(v[["value"]])) {
    out <- list(value = v[["value"]], source = v[["source"]])
    if (!is.null(v[["bands"]])) out <- c(conv_ratio(v[["bands"]], where), list(source = v[["source"]]))
    return(compact(out))
  }
  drop(where, "ratio in an unknown form", v)
  NULL
}

# ---- Zones ---------------------------------------------------------------------

handled_zone_fields <- c(
  "method", "label", "source", "notes", "height", "height_from_overlay", "storey_height_m",
  "coverage_max", "landscaping_min", "impervious_max", "paved_max", "far_max",
  "max_floorplate_m2", "max_tower_floorplate_m2", "max_tower_dimension_m", "tower_separation_m",
  "max_building_length_m", "building_separation_m", "tower_above_storey", "tower_above_height_m",
  "max_site_floorspace_m2", "site_shape_rectangle", "site_area_per_dwelling_m2",
  "land_area_per_dwelling_m2", "dwellings_per_hectare", "min_site_area_m2",
  "vacant_site_min_area_m2", "max_dwellings_per_site", "minor_dwellings_per_site",
  "minor_dwelling_source", "min_dwelling_size_m2", "large_site_area_per_dwelling_m2",
  "large_site_min_net_area_m2", "large_site_max_average_net_area_m2",
  "residential_enabled", "business_enabled", "residential_apportionment",
  "residential_apportionment_source", "access_width_applies", "variants", "yards", "hirb",
  "upper_level_setback", "label", "min_dwellings_total", "max_dwellings_total",
  "max_floorspace_total", "building_gaps_above_m"
)

# `partial = TRUE` converts an override (precinct, sub-precinct, overlay), where
# capacityengine's yards and hirb each replace the zone's whole set.
conv_zone <- function(z, where, bundle, partial = FALSE, totals_env = NULL) {
  for (f in setdiff(names(z), handled_zone_fields)) drop(where, f, z[[f]])
  if (!is.null(z[["cfgs_large_site_area_per_dwelling_m2"]])) {
    drop(where, "cfgs_large_site_area_per_dwelling_m2 (CfGS fidelity mode only)")
  }
  h <- z[["height"]]
  if (is.numeric(h)) h <- list(value = h)
  height <- NULL
  if (!is.null(h) || !is.null(z[["height_from_overlay"]])) {
    if (!is.null(h[["unit"]]) && h[["unit"]] != "m") drop(where, "height unit", h[["unit"]])
    height <- compact(list(value = h[["value"]], occupiable = h[["occupiable_value"]],
                           roof_allowance = h[["roof_form_value"]], storeys = h[["storeys"]],
                           from_overlay = z[["height_from_overlay"]], source = h[["source"]]))
    if (!length(height)) height <- NULL
  }
  setbacks <- list()
  kinds <- character()
  if (!is.null(z[["yards"]]) || ("yards" %in% names(z))) {
    kinds <- c(kinds, "yard")
    for (nm in names(z[["yards"]])) setbacks[[length(setbacks) + 1]] <- conv_yard(nm, z[["yards"]][[nm]], where)
  }
  if ("hirb" %in% names(z)) {
    kinds <- c(kinds, "plane")
    for (i in seq_along(z[["hirb"]])) setbacks[[length(setbacks) + 1]] <- conv_plane(z[["hirb"]][[i]], where, i)
  }
  if ("upper_level_setback" %in% names(z)) {
    kinds <- c(kinds, "upper_level")
    for (i in seq_along(z[["upper_level_setback"]])) {
      setbacks[[length(setbacks) + 1]] <- conv_uls(z[["upper_level_setback"]][[i]], where, i)
    }
  }
  setbacks <- compact(setbacks)
  ratios <- compact(list(
    coverage_max = conv_ratio(z[["coverage_max"]], paste0(where, "/coverage_max")),
    landscaping_min = conv_ratio(z[["landscaping_min"]], paste0(where, "/landscaping_min")),
    impervious_max = conv_ratio(z[["impervious_max"]], paste0(where, "/impervious_max")),
    paved_max = conv_ratio(z[["paved_max"]], paste0(where, "/paved_max")),
    far_max = conv_ratio(z[["far_max"]], paste0(where, "/far_max"))
  ))
  ss <- z[["site_shape_rectangle"]]
  form <- compact(list(
    max_floorplate = z[["max_floorplate_m2"]], max_tower_floorplate = z[["max_tower_floorplate_m2"]],
    tower_above_height = z[["tower_above_height_m"]], tower_above_storey = z[["tower_above_storey"]],
    max_tower_dimension = z[["max_tower_dimension_m"]], tower_separation = z[["tower_separation_m"]],
    max_building_length = z[["max_building_length_m"]],
    building_separation = if (!is.null(z[["building_separation_m"]]) && !is.null(z[["building_gaps_above_m"]])) {
      # Gaps that start above a height (capacityengine item 374) are a
      # separation of zero below it.
      list(bands = list(by = "height", bands = list(
        list(min = 0, max = z[["building_gaps_above_m"]], value = 0),
        list(min = z[["building_gaps_above_m"]], value = z[["building_separation_m"]]))))
    } else z[["building_separation_m"]],
    site_shape = if (!is.null(ss)) list(width = ss[["width_m"]], depth = ss[["length_m"]]),
    max_site_floorspace = z[["max_site_floorspace_m2"]],
    source = ss[["source"]]
  ))
  aw <- NULL
  residential <- z[["residential_enabled"]] %||% (if (!partial) TRUE)
  if (!partial && !isFALSE(z[["access_width_applies"]]) && isTRUE(residential) &&
      length(bundle[["access_width_table"]]) && (z[["method"]] %||% "") != "none") {
    aw <- lapply(bundle[["access_width_table"]], function(r) compact(list(
      min = r[["min_m"]], max = r[["max_m"]], max_dwellings = r[["max_dwellings"]])))
  }
  ls <- compact(list(area_per_dwelling = z[["large_site_area_per_dwelling_m2"]],
                     min_area = z[["large_site_min_net_area_m2"]],
                     max_average_area = z[["large_site_max_average_net_area_m2"]]))
  density <- compact(list(
    site_area_per_dwelling = z[["site_area_per_dwelling_m2"]] %||% z[["land_area_per_dwelling_m2"]],
    dwellings_per_ha = z[["dwellings_per_hectare"]], min_site_area = z[["min_site_area_m2"]],
    vacant_site_min_area = z[["vacant_site_min_area_m2"]],
    max_dwellings_per_site = z[["max_dwellings_per_site"]],
    minor_dwellings_per_site = z[["minor_dwellings_per_site"]],
    min_dwelling_size = z[["min_dwelling_size_m2"]],
    large_site = if (length(ls)) ls, access_width = aw,
    source = z[["minor_dwelling_source"]]
  ))
  ra <- unlist(z[["residential_apportionment"]])
  if (length(ra) > 1) {
    # Element-wise from the ground storey up, last value repeated.
    n <- length(ra)
    ra <- list(bands = list(by = "storey", bands = lapply(seq_len(n), function(i) compact(list(
      min = i - 1, max = if (i < n) i, value = ra[i])))))
  }
  use <- compact(list(
    residential = z[["residential_enabled"]] %||% (if (!partial) TRUE),
    business = z[["business_enabled"]] %||% (if (!partial) FALSE),
    residential_share = if (length(ra)) ra,
    source = z[["residential_apportionment_source"]]
  ))
  for (t in c("min_dwellings_total", "max_dwellings_total", "max_floorspace_total")) {
    if (!is.null(z[[t]])) {
      if (!is.null(totals_env)) totals_env[[sub("_total$", "", t)]] <- z[[t]]
      else drop(where, t, z[[t]])
    }
  }
  variants <- NULL
  if (length(z[["variants"]])) {
    variants <- c(list(standard = list(label = "Standard")),
                  stats::setNames(lapply(z[["variants"]], function(v) list(label = v)), unlist(z[["variants"]])))
  }
  compact(list(
    label = z[["label"]], method = z[["method"]], source = z[["source"]],
    notes = if (!is.null(z[["notes"]])) trimws(z[["notes"]]),
    height = height, storey_height = z[["storey_height_m"]],
    setbacks = if (length(setbacks)) setbacks,
    replaces_setbacks = if (partial && length(kinds)) kinds,
    ratios = if (length(ratios)) ratios, form = if (length(form)) form,
    density = if (length(density)) density, use = if (length(use)) use,
    variants = variants
  ))
}

# ---- Overlays ------------------------------------------------------------------

conv_overlay <- function(o, id, bundle) {
  where <- paste0("overlays/", id)
  map <- list(height_cap = c("height", "cap"), height_override = c("height", "replace"),
              height_surface = c("height_surface", "cap"), spatial_exclusion = c("exclusion", NA),
              parameter_override = c("parameters", "replace"), flag_only = c("flag", NA))
  tc <- map[[o[["type"]]]]
  handled <- c("type", "source_layer", "surface_raster", "precedence", "value", "value_field",
               "value_domain", "filter", "floor_value", "removes", "applies_to_zones",
               "overrides", "default_enabled", "source", "notes", "unit",
               "height_conversion_table", "passthrough_below_m", "passthrough_above_m",
               "between_bands")
  for (f in setdiff(names(o), handled)) drop(where, f, o[[f]])
  if (!is.null(o[["unit"]]) && o[["unit"]] != "m") drop(where, "unit", o[["unit"]])
  vm <- NULL
  if (!is.null(o[["value_domain"]])) {
    vm <- lapply(o[["value_domain"]], function(d) d[["height_m"]])
  }
  notes <- o[["notes"]]
  if (o[["type"]] == "height_surface" && !is.null(o[["source_layer"]]) && !is.null(o[["surface_raster"]])) {
    notes <- paste0(c(notes, paste0("Extent layer in capacityengine: ", o[["source_layer"]], ".")), collapse = " ")
  }
  if (o[["type"]] == "spatial_exclusion" && !is.null(o[["activity_status"]])) {
    notes <- paste(c(notes, paste("Activity status:", o[["activity_status"]])), collapse = " ")
  }
  compact(list(
    type = tc[1], layer = o[["surface_raster"]] %||% o[["source_layer"]],
    combine = if (!is.na(tc[2])) tc[2],
    value = o[["value"]], value_field = o[["value_field"]], value_map = vm,
    floor_value = o[["floor_value"]],
    height_conversion = if (!is.null(o[["height_conversion_table"]])) compact(list(
      table = lapply(o[["height_conversion_table"]], function(r) compact(list(
        total = r[["total_m"]], occupiable = r[["occupiable_m"]], source = r[["source"]]))),
      passthrough_below = o[["passthrough_below_m"]], passthrough_above = o[["passthrough_above_m"]],
      between = o[["between_bands"]] %||% "passthrough")),
    filter = if (!is.null(o[["filter"]])) lapply(o[["filter"]], function(v) as.list(unlist(v))),
    removes = if (tc[1] == "exclusion") o[["removes"]] %||% "all",
    applies_to_zones = if (!is.null(o[["applies_to_zones"]])) as.character(unlist(o[["applies_to_zones"]])),
    parameters = if (!is.null(o[["overrides"]])) conv_zone(o[["overrides"]], paste0(where, "/overrides"), bundle, partial = TRUE),
    enabled = o[["default_enabled"]] %||% TRUE, precedence = o[["precedence"]],
    source = o[["source"]], notes = if (!is.null(notes)) trimws(notes)
  ))
}

# ---- Precincts -----------------------------------------------------------------

norm_key <- function(x) gsub("^_|_$", "", gsub("[^a-z0-9]+", "_", tolower(x)))

conv_precinct <- function(p, key, bundle) {
  where <- paste0("precincts/", key)
  handled <- c("precinct_id", "source_layer", "layer_name", "applies_to_zones", "overrides",
               "additions", "zone_overrides", "sub_precinct_field", "sub_precincts", "source",
               "notes", "label")
  for (f in setdiff(names(p), handled)) drop(where, f, p[[f]])
  totals <- new.env()
  params <- if (!is.null(p[["overrides"]])) conv_zone(p[["overrides"]], paste0(where, "/overrides"), bundle, TRUE, totals)
  adds <- if (!is.null(p[["additions"]])) conv_zone(p[["additions"]], paste0(where, "/additions"), bundle, TRUE, totals)
  if (!is.null(adds)) adds[["replaces_setbacks"]] <- NULL
  zp <- if (!is.null(p[["zone_overrides"]])) lapply(names(p[["zone_overrides"]]), function(zk) {
    conv_zone(p[["zone_overrides"]][[zk]], paste0(where, "/zone_overrides/", zk), bundle, TRUE, totals)
  })
  if (!is.null(zp)) names(zp) <- names(p[["zone_overrides"]])
  sa <- if (!is.null(p[["sub_precincts"]])) lapply(names(p[["sub_precincts"]]), function(sk) {
    s <- p[["sub_precincts"]][[sk]]
    w <- paste0(where, "/sub_precincts/", sk)
    sub_totals <- new.env()
    body <- conv_zone(s[["overrides"]] %||% list(), w, bundle, TRUE, sub_totals)
    body[["label"]] <- body[["label"]] %||% s[["label"]]
    body[["source"]] <- body[["source"]] %||% s[["source"]]
    if (!is.null(s[["additions"]])) {
      ad <- conv_zone(s[["additions"]], paste0(w, "/additions"), bundle, TRUE, sub_totals)
      ad[["replaces_setbacks"]] <- NULL
      body[["additions"]] <- ad
    }
    if (!is.null(s[["zone_overrides"]])) {
      body[["zone_parameters"]] <- lapply(stats::setNames(names(s[["zone_overrides"]]), names(s[["zone_overrides"]])),
        function(zk) conv_zone(s[["zone_overrides"]][[zk]], paste0(w, "/zone_overrides/", zk), bundle, TRUE, sub_totals))
    }
    st <- as.list(sub_totals)
    if (length(st)) body[["totals"]] <- st
    body[["total_group"]] <- s[["dwelling_total_group"]]
    for (f in setdiff(names(s), c("label", "source", "overrides", "additions", "zone_overrides",
                                  "dwelling_total_group"))) drop(w, f, s[[f]])
    compact(body)
  })
  if (!is.null(sa)) names(sa) <- toupper(names(p[["sub_precincts"]]))
  tot <- as.list(totals)
  compact(list(
    label = p[["label"]] %||% p[["layer_name"]],
    layer = p[["source_layer"]] %||% "precincts",
    filter = list(precinct_key = list(norm_key(p[["layer_name"]] %||% key))),
    applies_to_zones = if (!is.null(p[["applies_to_zones"]])) as.character(unlist(p[["applies_to_zones"]])),
    combine = "replace",
    parameters = if (length(params)) params, additions = if (length(adds)) adds,
    zone_parameters = zp,
    sub_area_field = if (!is.null(sa)) p[["sub_precinct_field"]] %||% "sub_precinct",
    sub_areas = sa, totals = if (length(tot)) tot,
    source = paste0(c(p[["precinct_id"]], p[["source"]]), collapse = ": "),
    notes = if (!is.null(p[["notes"]])) trimws(p[["notes"]])
  ))
}

# ---- Whole bundle -----------------------------------------------------------------

convert_bundle <- function(path, name) {
  rm(list = ls(dropped), envir = dropped)
  b <- yaml::read_yaml(path, eval.expr = FALSE)
  for (f in setdiff(names(b), c("plan", "defaults", "zones", "alias_map", "unmodelled_zones",
                                "zone_families", "overlays", "precedence_rule", "zone_adjacency",
                                "access_width_table", "conversion", "precincts", "unmodelled_rules"))) {
    drop("bundle", f, b[[f]])
  }
  d <- b[["defaults"]]
  for (f in setdiff(names(d), c("storey_height_m", "min_floorplate_m2", "large_site_threshold_m2",
                                "large_site_infrastructure_deduction", "large_site_dwellings",
                                "no_limit_height_stand_in_m", "ground_floor_height_m"))) {
    drop("defaults", f, d[[f]])
  }
  conv <- b[["conversion"]]
  x <- list(
    schema_version = "0.1",
    plan = compact(list(
      id = b[["plan"]][["id"]], name = plan_names[[name]] %||% b[["plan"]][["id"]],
      jurisdiction = tools::toTitleCase(b[["plan"]][["council"]]), country = "NZ",
      effective_date = as.character(b[["plan"]][["effective_date"]]), source = b[["plan"]][["source"]], units = "m",
      hemisphere = "south",
      notes = paste("Converted from the capacityengine bundle", basename(path),
                    "by plancap data-raw/convert_capacityengine.R on", paste0(format(Sys.Date()), "."),
                    "Precinct areas match a precinct_key column holding the normalised precinct name."))),
    defaults = compact(list(
      storey_height = d[["storey_height_m"]], ground_floor_height = d[["ground_floor_height_m"]],
      min_floorplate = d[["min_floorplate_m2"]], level_reference = "ceiling",
      no_limit_height = d[["no_limit_height_stand_in_m"]],
      large_site = compact(list(threshold = d[["large_site_threshold_m2"]],
                                deduction = d[["large_site_infrastructure_deduction"]],
                                method = if (identical(d[["large_site_dwellings"]], "divisor")) "divisor"
                                         else if (!is.null(d[["large_site_dwellings"]])) "envelope")))),
    morphology = list(reserve_families = list("OPEN_SPACE_ANY")),
    conversion = compact(list(
      dwelling_size = conv[["dwelling_size_m2"]] %||% 120,
      efficiency = 1 / (1 + (conv[["circulation_allowance"]] %||% 0.2) + (conv[["storage_allowance"]] %||% 0.05)),
      min_one_dwelling = !is.null(conv[["min_one_dwelling_floor_m2"]]),
      min_one_dwelling_floor = conv[["min_one_dwelling_floor_m2"]],
      source = paste0("capacityengine conversion: ", conv[["dwelling_size_m2"]] %||% 120,
                      " m2 a dwelling plus ", conv[["circulation_allowance"]] %||% 0.2, " circulation and ",
                      conv[["storage_allowance"]] %||% 0.05, " storage. ", conv[["note"]] %||% ""))),
    ground = list(mode = "most_restrictive"),
    variant_choice = "max"
  )

  zone_key_of <- function(code) b[["alias_map"]][[code]] %||% code
  x[["zones"]] <- list()
  for (k in names(b[["zones"]])) x[["zones"]][[k]] <- conv_zone(b[["zones"]][[k]], paste0("zones/", k), b)
  for (code in names(b[["unmodelled_zones"]])) {
    if (is.null(b[["alias_map"]][[code]])) {
      x[["zones"]][[code]] <- list(label = as.character(b[["unmodelled_zones"]][[code]]), method = "none",
                              source = "Not modelled in capacityengine (no capacity)")
    }
  }
  x[["zone_map"]] <- c(lapply(b[["alias_map"]], as.character),
                  stats::setNames(as.list(setdiff(names(b[["unmodelled_zones"]]), names(b[["alias_map"]]))),
                                  setdiff(names(b[["unmodelled_zones"]]), names(b[["alias_map"]]))))
  # Families list codes in capacityengine; plancap families list zone keys.
  x[["zone_families"]] <- lapply(b[["zone_families"]], function(codes) unique(vapply(unlist(codes), zone_key_of, "")))
  # Families can also be used as adjacency tokens directly; keys of zones used
  # in conditions that are neither zones nor families are reported.
  for (adj in b[["zone_adjacency"]]) {
    k <- adj[["zone"]]
    extra <- conv_zone(compact(list(yards = adj[["yards"]], hirb = adj[["hirb"]])), paste0("zone_adjacency/", k), b, TRUE)
    for (s in extra[["setbacks"]]) {
      s[["when"]][["adjacent_zones"]] <- unique(c(s[["when"]][["adjacent_zones"]], if (adj[["adjacent_zone"]] != "any") adj[["adjacent_zone"]]))
      x[["zones"]][[k]][["setbacks"]][[length(x[["zones"]][[k]][["setbacks"]]) + 1]] <- s
    }
  }
  x[["overlays"]] <- lapply(stats::setNames(names(b[["overlays"]]), names(b[["overlays"]])),
                       function(id) conv_overlay(b[["overlays"]][[id]], id, b))
  if (length(b[["precincts"]])) {
    x[["areas"]] <- lapply(stats::setNames(names(b[["precincts"]]), names(b[["precincts"]])),
                      function(k) conv_precinct(b[["precincts"]][[k]], k, b))
  }
  effect <- c(increases_capacity = "understates", reduces_capacity = "overstates", unknown = "unknown")
  x[["unmodelled_rules"]] <- lapply(b[["unmodelled_rules"]], function(u) compact(list(
    rule = u[["rule"]], reason = trimws(u[["reason"]]),
    zones = if (!is.null(u[["zones"]])) as.character(unlist(u[["zones"]])),
    likely_effect = effect[[u[["likely_effect"]] %||% "unknown"]])))
  dl <- sort(ls(dropped))
  if (length(dl)) {
    x[["unmodelled_rules"]][[length(x[["unmodelled_rules"]]) + 1]] <- list(
      rule = "Fields of the capacityengine bundle with no plancap equivalent",
      reason = paste0(length(dl), " field(s) were not carried across; see data-raw/conversion/",
                      name, ".md in the plancap source."),
      likely_effect = "either")
  }
  list(rulebook = normalise_rulebook(x), dropped = vapply(dl, function(k) dropped[[k]], ""))
}

dir.create("data-raw/conversion", showWarnings = FALSE)
for (nm in names(bundles)) {
  cat("\n==", nm, "==\n")
  res <- convert_bundle(bundles[[nm]], nm)
  rb <- res[["rulebook"]]
  v <- validate_rulebook(rb)
  print(v)
  out <- file.path("inst/rulebooks", paste0(nm, ".yaml"))
  write_rulebook(rb, out)
  hdr <- c(
    paste0("# ", rb[["plan"]][["name"]], " (", rb[["plan"]][["jurisdiction"]], ")"),
    "#",
    paste0("# Converted from capacityengine's ", basename(bundles[[nm]]), " on ", format(Sys.Date()), "."),
    "# A dated worked example, maintained by the package author: check the plan",
    "# itself before relying on any value. Values carry their rule citation where
# the source bundle recorded one (validate_rulebook() lists those without).",
    "# Fields the conversion could not carry are listed in the unmodelled_rules",
    "# register and in data-raw/conversion/ in the package source.",
    "")
  writeLines(c(hdr, readLines(out)[-(1:2)]), out)
  rep <- c(paste0("# Conversion report: ", nm), "",
           paste0("Source: `", bundles[[nm]], "`  "),
           paste0("Converted: ", format(Sys.time(), "%Y-%m-%d %H:%M")), "",
           paste0("Validation: ", if (v[["valid"]]) "valid" else "INVALID", ", ",
                  sum(v[["issues"]][["severity"]] == "warning"), " warnings."), "",
           "## Fields not carried across", "",
           if (length(res[["dropped"]])) paste0("- `", names(res[["dropped"]]), "` ", ifelse(nzchar(res[["dropped"]]), paste0("(", res[["dropped"]], ")"), "")) else "None.",
           "", "## Validation issues", "",
           if (nrow(v[["issues"]])) paste0("- ", v[["issues"]][["severity"]], ": `", v[["issues"]][["path"]], "` ", v[["issues"]][["message"]]) else "None.")
  writeLines(rep, file.path("data-raw/conversion", paste0(nm, ".md")))
  cat(length(res[["dropped"]]), "fields dropped;", length(rb[["zones"]]), "zones,", length(rb[["overlays"]]),
      "overlays,", length(rb[["areas"]]), "areas\n")
}
