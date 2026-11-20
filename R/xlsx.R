#' Rulebooks as spreadsheets
#'
#' For people who would rather not write YAML or R, a rulebook can be kept as
#' an Excel workbook. `rulebook_template()` writes an annotated, empty workbook
#' (or one filled from an existing rulebook) with drop-down lists for every
#' choice; `read_rulebook()` reads it back.
#'
#' The workbook has one sheet per kind of rule:
#'
#' | Sheet | One row per |
#' |---|---|
#' | `plan` | setting (plan details, defaults, conversion, ground budget, morphology) |
#' | `zones` | zone: height, site ratios, building form, density, uses |
#' | `setbacks` | yard, plane or other setback, with its conditions |
#' | `bands` | band of a value that changes in steps (e.g. coverage by site area) |
#' | `families` | zone family |
#' | `overlays` | overlay |
#' | `areas` | precinct or other area |
#' | `changes` | set of zone changes made by an overlay, area or sub-area |
#' | `bonuses`, `entitlements` | bonus or entitlement |
#' | `unmodelled` | rule not modelled |
#' | `variants`, `unit_mix`, `access_width` | the rarer tables |
#' | `fields` | (read-only) what every column means |
#'
#' In `setbacks`, `bands` and `access_width`, the `target` column names what
#' the row belongs to: a zone key (`MRZ`), an overlay's changes
#' (`overlay:character`), an area's changes (`area:quarry`), an area's changes
#' for one zone (`area:quarry/zone:MRZ`) or a sub-area (`area:quarry/sub:B`).
#'
#' Lists inside a cell are comma-separated (`side, rear`). Any number may be a
#' formula, written as text (`max(3, 0.4 * H)`).
#'
#' @param path Path of the `.xlsx` file to write.
#' @param rb Optional rulebook to fill the template from.
#' @return `path`, invisibly.
#' @export
#' @examplesIf rlang::is_installed("openxlsx2")
#' f <- tempfile(fileext = ".xlsx")
#' rulebook_template(f)
#' openxlsx2::wb_load(f)$sheet_names
rulebook_template <- function(path, rb = NULL) {
  if (is.null(rb)) {
    rb <- rulebook("Name of the plan", id = "plan-id") |>
      add_zone(zone("ZONE1", "Example zone",
                    height = height_limit(11, roof_allowance = 1, storeys = 3,
                                          source = "Rule reference"),
                    setbacks = list(yard(1.5, "road", source = "Rule reference")),
                    coverage = ratio(0.5, source = "Rule reference")))
  }
  write_rulebook_xlsx(rb, path)
}

# ---- Column specification for a zone body -----------------------------------

zone_spec <- function() {
  s <- list(
    list("label", c("label"), "chr"),
    list("method", c("method"), "chr"),
    list("height", c("height", "value"), "value"),
    list("occupiable", c("height", "occupiable"), "num"),
    list("roof_allowance", c("height", "roof_allowance"), "num"),
    list("storeys", c("height", "storeys"), "num"),
    list("height_from_overlay", c("height", "from_overlay"), "chr"),
    list("height_datum", c("height", "datum"), "chr"),
    list("height_no_limit", c("height", "no_limit"), "lgl"),
    list("height_source", c("height", "source"), "chr"),
    list("storey_height", c("storey_height"), "num"),
    list("ground_floor_height", c("ground_floor_height"), "num")
  )
  for (r in c("coverage_max", "landscaping_min", "impervious_max", "paved_max",
              "far_max", "deep_soil_min")) {
    s[[length(s) + 1]] <- list(r, c("ratios", r, "value"), "value")
    s[[length(s) + 1]] <- list(paste0(r, "_source"), c("ratios", r, "source"), "chr")
  }
  for (f in c("max_floorplate", "min_floorplate", "max_tower_floorplate",
              "tower_above_height", "tower_above_storey", "max_tower_dimension",
              "tower_separation", "max_building_length", "building_separation",
              "max_building_depth", "min_building_width", "max_site_floorspace")) {
    s[[length(s) + 1]] <- list(f, c("form", f), "num")
  }
  s <- c(s, list(
    list("site_shape_width", c("form", "site_shape", "width"), "num"),
    list("site_shape_depth", c("form", "site_shape", "depth"), "num"),
    list("form_source", c("form", "source"), "chr")
  ))
  for (f in c("site_area_per_dwelling", "dwellings_per_ha", "min_site_area",
              "vacant_site_min_area", "max_dwellings_per_site",
              "minor_dwellings_per_site", "min_dwelling_size")) {
    s[[length(s) + 1]] <- list(f, c("density", f), "num")
  }
  c(s, list(
    list("large_site_area_per_dwelling", c("density", "large_site", "area_per_dwelling"), "num"),
    list("large_site_min_area", c("density", "large_site", "min_area"), "num"),
    list("large_site_max_average_area", c("density", "large_site", "max_average_area"), "num"),
    list("large_site_source", c("density", "large_site", "source"), "chr"),
    list("density_source", c("density", "source"), "chr"),
    list("residential", c("use", "residential"), "lgl"),
    list("business", c("use", "business"), "lgl"),
    list("residential_share", c("use", "residential_share"), "num"),
    list("use_source", c("use", "source"), "chr"),
    list("replaces_setbacks", c("replaces_setbacks"), "strs"),
    list("source", c("source"), "chr"),
    list("notes", c("notes"), "chr")
  ))
}

setback_cols <- c("target", "kind", "name", "boundaries", "distance", "from_storey",
                  "above_height", "angle_deg", "start_height", "set_in", "datum",
                  "ratio", "min", "max", "points", "angle_by_bearing", "angle_by_orientation",
                  "vertical_above", "max_setback_above", "origin")
condition_cols <- c("min_site_area", "max_site_area", "rear_sites", "corner_sites",
                    "within_frontage", "beyond_frontage", "frontage_depth_share",
                    "adjacent_zones", "not_adjacent_zones", "facing", "min_road_width",
                    "max_road_width", "min_slope", "max_slope", "distance_to",
                    "min_distance", "max_distance")
string_list_conditions <- c("adjacent_zones", "not_adjacent_zones")

get_path <- function(x, path) {
  for (p in path) {
    if (!is.list(x)) return(NULL)
    x <- x[[p]]
  }
  x
}

set_path <- function(x, path, value) {
  if (is.null(value)) return(x)
  if (length(path) == 1) {
    x[[path]] <- value
    return(x)
  }
  x[[path[1]]] <- set_path(x[[path[1]]] %||% list(), path[-1], value)
  x
}

cell <- function(v) {
  if (is.null(v) || (is.list(v) && !length(v))) return(NA)
  if (is.list(v)) return(NA)
  if (length(v) > 1) return(paste(v, collapse = ", "))
  v
}

split_list <- function(v) {
  if (is.null(v) || is.na(v) || !nzchar(trimws(v))) return(NULL)
  trimws(strsplit(as.character(v), ",", fixed = TRUE)[[1]])
}

from_cell <- function(v, type) {
  if (is.null(v) || length(v) == 0 || (length(v) == 1 && is.na(v))) return(NULL)
  if (is.character(v) && !nzchar(trimws(v))) return(NULL)
  switch(type,
    chr = as.character(v),
    num = {
      n <- suppressWarnings(as.numeric(v))
      if (is.na(n)) cli::cli_abort("Expected a number, found {.val {v}}.")
      n
    },
    lgl = {
      if (is.logical(v)) v else toupper(trimws(as.character(v))) %in% c("TRUE", "YES", "Y", "1")
    },
    value = {
      n <- suppressWarnings(as.numeric(v))
      if (!is.na(n)) n else trimws(as.character(v))
    },
    strs = split_list(v)
  )
}

# ---- Rulebook -> tables -------------------------------------------------------

rulebook_tables <- function(rb) {
  rb <- to_plain(rb)
  spec <- zone_spec()
  bands_rows <- list()
  setback_rows <- list()
  aw_rows <- list()
  variant_rows <- list()

  zone_row <- function(z, target) {
    row <- lapply(spec, function(s) {
      v <- get_path(z, s[[2]])
      if (s[[3]] == "value" && is.list(v)) NA else cell(v)
    })
    names(row) <- vapply(spec, `[[`, "", 1)
    # Banded values go to the bands sheet
    for (r in names(z$ratios)) {
      b <- z$ratios[[r]]$bands
      if (!is.null(b)) add_band_rows(b, target, r)
    }
    bs <- z$form$building_separation
    if (is.list(bs) && !is.null(bs$bands)) {
      add_band_rows(bs$bands, target, "building_separation")
      row$building_separation <- NA
    }
    rs <- z$use$residential_share
    if (is.list(rs) && !is.null(rs$bands)) {
      add_band_rows(rs$bands, target, "residential_share")
      row$residential_share <- NA
    }
    for (s in z$setbacks) add_setback_row(s, target)
    for (a in z$density$access_width) {
      aw_rows[[length(aw_rows) + 1]] <<- data.frame(
        target = target, min = a$min %||% NA, max = a$max %||% NA,
        max_dwellings = a$max_dwellings %||% NA)
    }
    for (v in names(z$variants)) {
      variant_rows[[length(variant_rows) + 1]] <<- data.frame(
        target = target, variant = v, label = z$variants[[v]]$label %||% NA,
        source = z$variants[[v]]$source %||% NA)
    }
    as.data.frame(row, stringsAsFactors = FALSE)
  }
  add_band_rows <- function(b, target, rule) {
    for (i in seq_along(b$bands)) {
      x <- b$bands[[i]]
      bands_rows[[length(bands_rows) + 1]] <<- data.frame(
        target = target, rule = rule, by = b$by, upper = x$max %||% NA,
        value = as.character(x$value), source = if (i == 1) b$source %||% NA else NA,
        stringsAsFactors = FALSE)
    }
  }
  add_setback_row <- function(s, target) {
    row <- list(target = target, kind = s$kind, name = s$name %||% NA,
                boundaries = cell(s$boundaries), distance = cell(s$distance),
                from_storey = cell(s$from_storey), above_height = cell(s$above_height),
                angle_deg = cell(s$angle_deg), start_height = cell(s$start_height),
                set_in = cell(s$set_in), datum = cell(s$datum), ratio = cell(s$ratio),
                min = cell(s$min), max = cell(s$max),
                points = if (!is.null(s$points)) paste(vapply(s$points, function(p)
                  paste(unlist(p), collapse = ":"), ""), collapse = "; ") else NA,
                angle_by_bearing = if (!is.null(s$angle_by_bearing)) paste(vapply(
                  s$angle_by_bearing, function(a) paste0(a$from_deg, "-", a$to_deg, ":", a$angle_deg),
                  ""), collapse = "; ") else NA,
                angle_by_orientation = fmt_kv(s$angle_by_orientation),
                vertical_above = cell(s$vertical_above),
                max_setback_above = fmt_kv(s$max_setback_above),
                origin = cell(s$origin))
    for (cc in condition_cols) row[[cc]] <- cell(s$when[[cc]])
    row$variant <- cell(s$variant)
    row$activity_status <- cell(s$activity_status)
    row$source <- cell(s$source)
    setback_rows[[length(setback_rows) + 1]] <<- as.data.frame(lapply(row, as.character),
                                                               stringsAsFactors = FALSE)
  }

  codes <- if (length(rb$zone_map)) {
    split(names(rb$zone_map), unlist(rb$zone_map, use.names = FALSE))
  } else {
    list()
  }
  zones <- do.call(rbind, c(list(empty_zone_df(spec)), lapply(names(rb$zones), function(k) {
    r <- zone_row(rb$zones[[k]], k)
    cbind(data.frame(zone = k, codes = paste(codes[[k]] %||% character(), collapse = ", "),
                     stringsAsFactors = FALSE), r)
  })))
  changes <- list()
  for (o in names(rb$overlays)) {
    p <- rb$overlays[[o]]$parameters
    if (!is.null(p)) changes[[length(changes) + 1]] <- cbind(target = paste0("overlay:", o), zone_row(p, paste0("overlay:", o)))
    ad <- rb$overlays[[o]]$additions
    if (!is.null(ad)) {
      t2 <- paste0("overlay:", o, "/additions")
      changes[[length(changes) + 1]] <- cbind(target = t2, zone_row(ad, t2))
    }
  }
  for (a in names(rb$areas)) {
    ar <- rb$areas[[a]]
    tg <- paste0("area:", a)
    if (!is.null(ar$parameters)) changes[[length(changes) + 1]] <- cbind(target = tg, zone_row(ar$parameters, tg))
    if (!is.null(ar$additions)) {
      t2 <- paste0(tg, "/additions")
      changes[[length(changes) + 1]] <- cbind(target = t2, zone_row(ar$additions, t2))
    }
    for (zk in names(ar$zone_parameters)) {
      t2 <- paste0(tg, "/zone:", zk)
      changes[[length(changes) + 1]] <- cbind(target = t2, zone_row(ar$zone_parameters[[zk]], t2))
    }
    for (sk in names(ar$sub_areas)) {
      sa <- ar$sub_areas[[sk]]
      t2 <- paste0(tg, "/sub:", sk)
      changes[[length(changes) + 1]] <- cbind(
        target = t2, zone_row(sa, t2),
        max_dwellings = cell(sa$totals$max_dwellings), min_dwellings = cell(sa$totals$min_dwellings),
        max_floorspace = cell(sa$totals$max_floorspace), total_group = cell(sa$total_group))
      if (!is.null(sa$additions)) {
        t3 <- paste0(t2, "/additions")
        changes[[length(changes) + 1]] <- cbind(target = t3, zone_row(sa$additions, t3))
      }
      for (zk in names(sa$zone_parameters)) {
        t3 <- paste0(t2, "/zone:", zk)
        changes[[length(changes) + 1]] <- cbind(target = t3, zone_row(sa$zone_parameters[[zk]], t3))
      }
    }
  }
  sub_cols <- c("max_dwellings", "min_dwellings", "max_floorspace", "total_group")
  changes <- lapply(changes, function(df) {
    for (cc in setdiff(sub_cols, names(df))) df[[cc]] <- NA
    df
  })
  changes <- do.call(rbind, c(list(cbind(target = character(), empty_zone_df(spec),
                                         empty_df(sub_cols))), changes))

  kv <- function(section, x) {
    if (is.null(x) || !length(x)) return(NULL)
    data.frame(section = section, key = names(x),
               value = vapply(x, function(v) if (is.list(v)) NA_character_ else paste(v, collapse = ", "), ""),
               stringsAsFactors = FALSE)
  }
  ls <- rb$defaults$large_site
  conv <- rb$conversion
  conv$unit_mix <- NULL
  plan <- rbind(
    kv("plan", rb$plan),
    kv("plan", list(variant_choice = rb$variant_choice)),
    kv("defaults", rb$defaults[setdiff(names(rb$defaults), "large_site")]),
    kv("defaults", if (!is.null(ls)) stats::setNames(ls, paste0("large_site_", names(ls)))),
    kv("conversion", conv),
    kv("ground", rb$ground[setdiff(names(rb$ground), "overlap")]),
    kv("ground", if (!is.null(rb$ground$overlap)) stats::setNames(rb$ground$overlap, paste0("overlap_", names(rb$ground$overlap)))),
    kv("morphology", rb$morphology)
  )

  families <- data.frame(family = names(rb$zone_families),
                         zones = vapply(rb$zone_families, function(f) paste(family_zones(f), collapse = ", "), ""),
                         min_area = vapply(rb$zone_families, function(f) if (is.list(f)) f$min_area %||% NA_real_ else NA_real_, 0),
                         max_area = vapply(rb$zone_families, function(f) if (is.list(f)) f$max_area %||% NA_real_ else NA_real_, 0),
                         stringsAsFactors = FALSE)
  ov_cols <- c("id", "label", "type", "layer", "combine", "value", "value_field", "value_map",
               "floor_value", "filter", "removes", "buffer", "applies_to_zones", "enabled",
               "precedence", "source", "notes")
  overlays <- do.call(rbind, c(list(empty_df(ov_cols)), lapply(names(rb$overlays), function(o) {
    x <- rb$overlays[[o]]
    data.frame(id = o, label = cell(x$label), type = x$type, layer = x$layer,
               combine = cell(x$combine), value = as.character(cell(x[["value"]])),
               value_field = cell(x[["value_field"]]),
               value_map = if (!is.null(x$value_map)) paste(names(x$value_map), unlist(x$value_map), sep = "=", collapse = "; ") else NA,
               floor_value = cell(x$floor_value), filter = fmt_filter(x$filter),
               removes = cell(x$removes), buffer = as.character(cell(x$buffer)),
               applies_to_zones = cell(x$applies_to_zones), enabled = cell(x$enabled),
               precedence = cell(x$precedence), source = cell(x$source), notes = cell(x$notes),
               stringsAsFactors = FALSE)
  })))
  ar_cols <- c("id", "label", "layer", "filter", "applies_to_zones", "combine", "sub_area_field",
               "max_dwellings", "min_dwellings", "max_floorspace", "source", "notes")
  areas <- do.call(rbind, c(list(empty_df(ar_cols)), lapply(names(rb$areas), function(a) {
    x <- rb$areas[[a]]
    data.frame(id = a, label = cell(x$label), layer = x$layer, filter = fmt_filter(x$filter),
               applies_to_zones = cell(x$applies_to_zones), combine = cell(x$combine),
               sub_area_field = cell(x$sub_area_field),
               max_dwellings = cell(x$totals$max_dwellings), min_dwellings = cell(x$totals$min_dwellings),
               max_floorspace = cell(x$totals$max_floorspace), source = cell(x$source),
               notes = cell(x$notes), stringsAsFactors = FALSE)
  })))
  bo_cols <- c("id", "label", "quantity", "value", "combine", "applies_to_zones", "cap",
               "condition", "layer", "source")
  bonuses <- do.call(rbind, c(list(empty_df(bo_cols)), lapply(names(rb$bonuses), function(b) {
    x <- rb$bonuses[[b]]
    data.frame(id = b, label = cell(x$label), quantity = x$quantity, value = as.character(x[["value"]]),
               combine = x$combine, applies_to_zones = cell(x$applies_to_zones), cap = cell(x$cap),
               condition = cell(x$condition), layer = cell(x$layer), source = cell(x$source),
               stringsAsFactors = FALSE)
  })))
  en_cols <- c("id", "label", "quantity", "value", "applies_to_zones", "layer", "source")
  entitlements <- do.call(rbind, c(list(empty_df(en_cols)), lapply(names(rb$entitlements), function(e) {
    x <- rb$entitlements[[e]]
    data.frame(id = e, label = cell(x$label), quantity = x$quantity, value = x[["value"]],
               applies_to_zones = cell(x$applies_to_zones), layer = cell(x$layer),
               source = cell(x$source), stringsAsFactors = FALSE)
  })))
  un_cols <- c("rule", "reason", "zones", "likely_effect", "size", "source")
  unmodelled <- do.call(rbind, c(list(empty_df(un_cols)), lapply(rb$unmodelled_rules, function(u) {
    data.frame(rule = u$rule, reason = u$reason, zones = cell(u$zones),
               likely_effect = cell(u$likely_effect), size = cell(u$size),
               source = cell(u$source), stringsAsFactors = FALSE)
  })))
  unit_mix <- do.call(rbind, c(list(empty_df(c("name", "size", "share"))),
                               lapply(rb$conversion$unit_mix, as.data.frame)))

  bind <- function(rows, cols) do.call(rbind, c(list(empty_df(cols)), rows))
  list(
    plan = plan %||% empty_df(c("section", "key", "value")),
    zones = zones,
    setbacks = bind(setback_rows, c(setback_cols, condition_cols, "variant", "activity_status", "source")),
    bands = bind(bands_rows, c("target", "rule", "by", "upper", "value", "source")),
    families = families,
    overlays = overlays,
    areas = areas,
    changes = changes,
    bonuses = bonuses,
    entitlements = entitlements,
    unmodelled = unmodelled,
    variants = bind(variant_rows, c("target", "variant", "label", "source")),
    unit_mix = unit_mix,
    access_width = bind(aw_rows, c("target", "min", "max", "max_dwellings"))
  )
}

empty_df <- function(cols) {
  as.data.frame(stats::setNames(replicate(length(cols), character(), simplify = FALSE), cols),
                stringsAsFactors = FALSE)
}
empty_zone_df <- function(spec) {
  cbind(empty_df(c("zone", "codes")), empty_df(vapply(spec, `[[`, "", 1)))
}

fmt_kv <- function(x) {
  if (is.null(x) || !length(x)) return(NA)
  paste(names(x), unlist(x), sep = "=", collapse = ", ")
}
parse_kv <- function(v) {
  if (is.null(v)) return(NULL)
  parts <- strsplit(trimws(strsplit(v, ",", fixed = TRUE)[[1]]), "=", fixed = TRUE)
  stats::setNames(lapply(parts, function(p) as.numeric(trimws(p[2]))),
                  vapply(parts, function(p) trimws(p[1]), ""))
}

fmt_filter <- function(f) {
  if (is.null(f) || !length(f)) return(NA)
  paste(vapply(names(f), function(n) paste0(n, "=", paste(f[[n]], collapse = "|")), ""),
        collapse = "; ")
}
parse_filter <- function(v) {
  if (is.null(v) || is.na(v) || !nzchar(v)) return(NULL)
  parts <- trimws(strsplit(v, ";", fixed = TRUE)[[1]])
  out <- list()
  for (p in parts) {
    kv <- strsplit(p, "=", fixed = TRUE)[[1]]
    out[[trimws(kv[1])]] <- trimws(strsplit(kv[2], "|", fixed = TRUE)[[1]])
  }
  out
}

# ---- Tables -> rulebook -------------------------------------------------------

tables_to_rulebook <- function(t) {
  spec <- zone_spec()
  na_row <- function(df, i, col) if (col %in% names(df)) df[[col]][i] else NA

  body_from_row <- function(df, i) {
    z <- list()
    for (s in spec) {
      v <- from_cell(na_row(df, i, s[[1]]), s[[3]])
      z <- set_path(z, s[[2]], v)
    }
    z
  }
  attach_extras <- function(z, target) {
    sb <- t$setbacks[t$setbacks$target %in% target, , drop = FALSE]
    if (nrow(sb)) z$setbacks <- lapply(seq_len(nrow(sb)), function(i) setback_from_row(sb, i))
    bd <- t$bands[t$bands$target %in% target, , drop = FALSE]
    for (rule in unique(bd$rule)) {
      b <- bd[bd$rule == rule, , drop = FALSE]
      bobj <- band_obj(b)
      if (rule %in% c("coverage_max", "landscaping_min", "impervious_max", "paved_max",
                      "far_max", "deep_soil_min")) {
        z$ratios[[rule]]$bands <- bobj
        z$ratios[[rule]]$value <- NULL
      } else if (rule == "building_separation") {
        z$form$building_separation <- list(bands = bobj)
      } else if (rule == "residential_share") {
        z$use$residential_share <- list(bands = bobj)
      }
    }
    aw <- t$access_width[t$access_width$target %in% target, , drop = FALSE]
    if (nrow(aw)) {
      z$density$access_width <- lapply(seq_len(nrow(aw)), function(i) compact(list(
        min = from_cell(aw$min[i], "num"), max = from_cell(aw$max[i], "num"),
        max_dwellings = from_cell(aw$max_dwellings[i], "num"))))
    }
    va <- t$variants[t$variants$target %in% target, , drop = FALSE]
    if (nrow(va)) {
      z$variants <- stats::setNames(lapply(seq_len(nrow(va)), function(i) compact(list(
        label = from_cell(va$label[i], "chr"), source = from_cell(va$source[i], "chr")))), va$variant)
    }
    z
  }

  plan <- t$plan
  get_kv <- function(section) {
    p <- plan[plan$section == section, , drop = FALSE]
    stats::setNames(as.list(p$value), p$key)
  }
  num_or_chr <- function(v) from_cell(v, "value")
  pl <- get_kv("plan")
  x <- list(schema_version = rulebook_schema_version())
  x$plan <- compact(lapply(pl[setdiff(names(pl), "variant_choice")], from_cell, type = "chr"))
  x$variant_choice <- from_cell(pl$variant_choice, "chr")
  d <- lapply(get_kv("defaults"), num_or_chr)
  ls_keys <- grep("^large_site_", names(d), value = TRUE)
  x$defaults <- compact(d[setdiff(names(d), ls_keys)])
  if (length(ls_keys)) x$defaults$large_site <- compact(stats::setNames(d[ls_keys], sub("^large_site_", "", ls_keys)))
  conv <- compact(lapply(get_kv("conversion"), num_or_chr))
  if (!is.null(conv$min_one_dwelling)) conv$min_one_dwelling <- from_cell(conv$min_one_dwelling, "lgl")
  if (nrow(t$unit_mix)) {
    conv$unit_mix <- lapply(seq_len(nrow(t$unit_mix)), function(i) list(
      name = as.character(t$unit_mix$name[i]), size = as.numeric(t$unit_mix$size[i]),
      share = as.numeric(t$unit_mix$share[i])))
  }
  if (length(conv)) x$conversion <- conv
  g <- compact(lapply(get_kv("ground"), num_or_chr))
  ov_keys <- grep("^overlap_", names(g), value = TRUE)
  if (length(g)) {
    x$ground <- g[setdiff(names(g), ov_keys)]
    if (length(ov_keys)) x$ground$overlap <- lapply(stats::setNames(g[ov_keys], sub("^overlap_", "", ov_keys)),
                                                    from_cell, type = "lgl")
  }
  m <- compact(lapply(get_kv("morphology"), num_or_chr))
  if (!is.null(m$exclude_access_legs)) m$exclude_access_legs <- from_cell(m$exclude_access_legs, "lgl")
  if (!is.null(m$reserve_families)) m$reserve_families <- split_list(m$reserve_families)
  if (length(m)) x$morphology <- m

  if (nrow(t$families)) {
    x$zone_families <- stats::setNames(lapply(seq_len(nrow(t$families)), function(i) {
      z <- split_list(t$families$zones[i])
      lo <- from_cell(t$families$min_area[i] %||% NA, "num")
      hi <- from_cell(t$families$max_area[i] %||% NA, "num")
      if (is.null(lo) && is.null(hi)) z else compact(list(zones = z, min_area = lo, max_area = hi))
    }), t$families$family)
  }
  x$zones <- list()
  x$zone_map <- list()
  for (i in seq_len(nrow(t$zones))) {
    k <- t$zones$zone[i]
    x$zones[[k]] <- attach_extras(compact_deep(body_from_row(t$zones, i)), k)
    for (code in split_list(t$zones$codes[i]) %||% k) x$zone_map[[code]] <- k
  }
  changes_for <- function(target) {
    j <- which(t$changes$target == target)
    if (!length(j)) {
      has_extra <- any(t$setbacks$target == target) || any(t$bands$target == target)
      if (!has_extra) return(NULL)
      return(attach_extras(list(), target))
    }
    attach_extras(compact_deep(body_from_row(t$changes, j[1])), target)
  }
  for (i in seq_len(nrow(t$overlays))) {
    o <- t$overlays[i, ]
    id <- o$id
    vm <- from_cell(o$value_map, "chr")
    x$overlays[[id]] <- compact(list(
      label = from_cell(o$label, "chr"), type = o$type, layer = o$layer,
      combine = from_cell(o$combine, "chr"), value = from_cell(o[["value"]], "value"),
      value_field = from_cell(o[["value_field"]], "chr"),
      value_map = if (!is.null(vm)) {
        kv <- strsplit(trimws(strsplit(vm, ";", fixed = TRUE)[[1]]), "=", fixed = TRUE)
        stats::setNames(lapply(kv, function(p) as.numeric(p[2])), vapply(kv, `[`, "", 1))
      },
      floor_value = from_cell(o$floor_value, "num"), filter = parse_filter(o$filter),
      removes = from_cell(o$removes, "chr"), buffer = from_cell(o$buffer, "value"),
      applies_to_zones = split_list(o$applies_to_zones),
      parameters = changes_for(paste0("overlay:", id)),
      additions = changes_for(paste0("overlay:", id, "/additions")),
      enabled = from_cell(o$enabled, "lgl"), precedence = from_cell(o$precedence, "num"),
      source = from_cell(o$source, "chr"), notes = from_cell(o$notes, "chr")))
  }
  for (i in seq_len(nrow(t$areas))) {
    a <- t$areas[i, ]
    id <- a$id
    tg <- paste0("area:", id)
    zp_targets <- unique(grep(paste0("^", tg, "/zone:"), c(t$changes$target, t$setbacks$target, t$bands$target), value = TRUE))
    all_t <- c(t$changes$target, t$setbacks$target, t$bands$target)
    sa_targets <- unique(grep(paste0("^", tg, "/sub:[^/]+$"), all_t, value = TRUE))
    zp <- stats::setNames(lapply(zp_targets, changes_for), sub(".*/zone:", "", zp_targets))
    sa <- stats::setNames(lapply(sa_targets, function(st) {
      body <- changes_for(st) %||% list()
      j <- which(t$changes$target == st)
      ad <- changes_for(paste0(st, "/additions"))
      zt <- unique(grep(paste0("^", st, "/zone:"), all_t, value = TRUE))
      zpp <- stats::setNames(lapply(zt, changes_for), sub(".*/zone:", "", zt))
      tot <- if (length(j)) compact(list(
        max_dwellings = from_cell(na_row(t$changes, j[1], "max_dwellings"), "num"),
        min_dwellings = from_cell(na_row(t$changes, j[1], "min_dwellings"), "num"),
        max_floorspace = from_cell(na_row(t$changes, j[1], "max_floorspace"), "num")))
      compact(c(body, list(
        additions = ad, zone_parameters = if (length(zpp)) zpp,
        totals = if (length(tot)) tot,
        total_group = if (length(j)) from_cell(na_row(t$changes, j[1], "total_group"), "chr"))))
    }), sub(".*/sub:", "", sa_targets))
    totals <- compact(list(max_dwellings = from_cell(a$max_dwellings, "num"),
                           min_dwellings = from_cell(a$min_dwellings, "num"),
                           max_floorspace = from_cell(a$max_floorspace, "num")))
    x$areas[[id]] <- compact(list(
      label = from_cell(a$label, "chr"), layer = a$layer, filter = parse_filter(a$filter),
      applies_to_zones = split_list(a$applies_to_zones), combine = from_cell(a$combine, "chr"),
      parameters = changes_for(tg),
      additions = changes_for(paste0(tg, "/additions")),
      zone_parameters = if (length(zp)) zp, sub_area_field = from_cell(a$sub_area_field, "chr"),
      sub_areas = if (length(sa)) sa, totals = if (length(totals)) totals,
      source = from_cell(a$source, "chr"), notes = from_cell(a$notes, "chr")))
  }
  for (i in seq_len(nrow(t$bonuses))) {
    b <- t$bonuses[i, ]
    x$bonuses[[b$id]] <- compact(list(
      label = from_cell(b$label, "chr"), quantity = b$quantity, value = from_cell(b[["value"]], "value"),
      combine = b$combine, applies_to_zones = split_list(b$applies_to_zones),
      cap = from_cell(b$cap, "num"), condition = from_cell(b$condition, "chr"),
      layer = from_cell(b$layer, "chr"), source = from_cell(b$source, "chr")))
  }
  for (i in seq_len(nrow(t$entitlements))) {
    e <- t$entitlements[i, ]
    x$entitlements[[e$id]] <- compact(list(
      label = from_cell(e$label, "chr"), quantity = e$quantity, value = from_cell(e[["value"]], "num"),
      combine = "floor", applies_to_zones = split_list(e$applies_to_zones),
      layer = from_cell(e$layer, "chr"), source = from_cell(e$source, "chr")))
  }
  if (nrow(t$unmodelled)) {
    x$unmodelled_rules <- lapply(seq_len(nrow(t$unmodelled)), function(i) {
      u <- t$unmodelled[i, ]
      compact(list(rule = u$rule, reason = u$reason, zones = split_list(u$zones),
                   likely_effect = from_cell(u$likely_effect, "chr"),
                   size = from_cell(u$size, "chr"), source = from_cell(u$source, "chr")))
    })
  }
  normalise_rulebook(compact(x))
}

band_obj <- function(b) {
  ups <- vapply(b$upper, function(u) from_cell(u, "num") %||% Inf, numeric(1))
  o <- order(ups)
  b <- b[o, , drop = FALSE]
  ups <- ups[o]
  lows <- c(0, utils::head(ups, -1))
  src <- stats::na.omit(b$source)
  compact(list(by = b$by[1], bands = lapply(seq_len(nrow(b)), function(i) compact(list(
    min = lows[i], max = if (is.finite(ups[i])) ups[i],
    value = from_cell(b[["value"]][i], "value")))),
    source = if (length(src)) src[[1]]))
}

setback_from_row <- function(sb, i) {
  g <- function(col, type = "chr") if (col %in% names(sb)) from_cell(sb[[col]][i], type) else NULL
  pts <- g("points")
  aby <- g("angle_by_bearing")
  when <- list()
  for (cc in condition_cols) {
    v <- g(cc)
    if (is.null(v)) next
    when[[cc]] <- if (cc %in% string_list_conditions) split_list(v)
                  else if (cc == "facing") as.numeric(split_list(v))
                  else if (cc %in% c("rear_sites", "corner_sites", "distance_to")) v
                  else from_cell(v, "num")
  }
  compact(list(
    kind = g("kind"), name = g("name"), distance = g("distance", "value"),
    from_storey = g("from_storey", "num"), above_height = g("above_height", "num"),
    angle_deg = g("angle_deg", "num"), start_height = g("start_height", "value"),
    set_in = g("set_in", "num"), datum = g("datum"), ratio = g("ratio", "num"),
    min = g("min", "num"), max = g("max", "num"),
    points = if (!is.null(pts)) lapply(strsplit(trimws(strsplit(pts, ";", fixed = TRUE)[[1]]), ":", fixed = TRUE), as.numeric),
    angle_by_bearing = if (!is.null(aby)) lapply(trimws(strsplit(aby, ";", fixed = TRUE)[[1]]), function(p) {
      parts <- as.numeric(strsplit(sub("^(-?[0-9.]+)-(-?[0-9.]+):", "\\1;\\2;", p), ";", fixed = TRUE)[[1]])
      list(from_deg = parts[1], to_deg = parts[2], angle_deg = parts[3])
    }),
    angle_by_orientation = parse_kv(g("angle_by_orientation")),
    vertical_above = g("vertical_above", "num"),
    max_setback_above = parse_kv(g("max_setback_above")),
    boundaries = split_list(g("boundaries")), origin = g("origin"),
    when = if (length(when)) when, variant = g("variant"),
    activity_status = g("activity_status"), source = g("source")
  ))
}

compact_deep <- function(x) {
  if (!is.list(x)) return(x)
  x <- lapply(x, compact_deep)
  x[!vapply(x, function(e) is.null(e) || (is.list(e) && !length(e)), logical(1))]
}

# ---- Workbook I/O -------------------------------------------------------------

field_notes <- function() {
  data.frame(
    sheet = c("zones", "zones", "zones", "zones", "zones", "zones", "setbacks", "setbacks",
              "setbacks", "setbacks", "setbacks", "setbacks", "bands", "bands", "overlays",
              "overlays", "areas", "changes", "unmodelled"),
    column = c("zone", "codes", "method", "height", "occupiable", "coverage_max", "target",
               "kind", "boundaries", "distance", "angle_deg / start_height / set_in",
               "adjacent_zones ...", "rule", "upper", "type", "combine", "layer", "target",
               "likely_effect"),
    meaning = c(
      "Zone key, used everywhere else in the workbook.",
      "Zone codes in the zoning layer that map to this zone, comma-separated.",
      "volumetric, density, hybrid or none (no capacity; kept for neighbour rules).",
      "Maximum height including any roof allowance (m), or a formula.",
      "Height up to which floors may be built (m).",
      "Maximum building coverage as a share of net site area (0-1). For coverage that changes with site area, leave blank and use the bands sheet.",
      "A zone key, or overlay:ID, area:ID, area:ID/zone:ZONE, area:ID/sub:SUB.",
      "yard, plane, upper_level, proportional or profile.",
      "Boundary classes, comma-separated: road, side, rear, internal, common, coastal, riparian, lakeside, reserve, rail.",
      "Required distance (m) or a formula such as max(3, 0.4 * H).",
      "For planes: angle from horizontal, height where it starts, and how far inside the boundary.",
      "Conditions: the rule applies only where all filled-in conditions hold.",
      "coverage_max, landscaping_min, impervious_max, paved_max, far_max, deep_soil_min, building_separation or residential_share.",
      "Upper bound of the band (blank = no upper bound). Bands are closed on the right.",
      "height, height_surface, exclusion, parameters or flag.",
      "cap (most restrictive wins), replace, floor, add or multiply.",
      "Name of the map layer supplied when the rulebook is run.",
      "What the changes apply to: overlay:ID, area:ID, area:ID/zone:ZONE or area:ID/sub:SUB.",
      "overstates (leaving it out overstates capacity), understates, either or unknown."),
    stringsAsFactors = FALSE)
}

write_rulebook_xlsx <- function(rb, path) {
  rlang::check_installed("openxlsx2", reason = "to write rulebook spreadsheets.")
  t <- rulebook_tables(rb)
  wb <- openxlsx2::wb_workbook(creator = "plancap")
  readme <- data.frame(plancap = c(
    paste("Rulebook:", rb$plan$name),
    "Fill in one row per rule. Every value should have a source: the plan, chapter and rule number.",
    "Lengths in metres (or feet if the plan sheet says units = ft); areas in square metres; shares as decimals (0.5 = 50%).",
    "Any number may be a formula, written as text, e.g. max(3, 0.4 * H). See ?rule-formulas.",
    "Lists inside a cell are comma-separated, e.g. side, rear.",
    "The fields sheet explains the less obvious columns. Read with plancap::read_rulebook()."))
  sheets <- c(list(README = readme), t, list(fields = field_notes()))
  dropdowns <- list(
    zones = list(method = c("volumetric", "density", "hybrid", "none"),
                 height_datum = c("ground", "finished", "average", "road", "sea_level")),
    setbacks = list(kind = c("yard", "plane", "upper_level", "proportional", "profile"),
                    origin = c("boundary", "road_far_side", "road_centreline"),
                    datum = c("boundary", "site", "road"),
                    rear_sites = c("include", "exclude", "only"),
                    corner_sites = c("include", "exclude", "only")),
    bands = list(by = c("site_area", "height", "storey", "slope", "road_width", "distance", "site_depth")),
    overlays = list(type = c("height", "height_surface", "exclusion", "parameters", "flag"),
                    combine = c("cap", "replace", "floor", "add", "multiply"),
                    removes = c("all", "residential")),
    areas = list(combine = c("replace", "cap")),
    bonuses = list(quantity = c("far", "height", "dwellings", "floor_area"),
                   combine = c("add", "multiply")),
    entitlements = list(quantity = c("dwellings", "height", "floor_area")),
    unmodelled = list(likely_effect = c("overstates", "understates", "either", "unknown"))
  )
  for (nm in names(sheets)) {
    df <- sheets[[nm]]
    wb$add_worksheet(nm)
    wb$add_data(sheet = nm, x = df, na.strings = "")
    nc <- max(1, ncol(df))
    if (nm != "README") {
      wb$add_font(sheet = nm, dims = openxlsx2::wb_dims(rows = 1, cols = seq_len(nc)), bold = TRUE)
      wb$add_fill(sheet = nm, dims = openxlsx2::wb_dims(rows = 1, cols = seq_len(nc)), color = openxlsx2::wb_color("FFDCE6F0"))
      wb$freeze_pane(sheet = nm, first_row = TRUE)
    }
    wb$set_col_widths(sheet = nm, cols = seq_len(nc), widths = if (nm == "README") 110 else 16)
    for (col in names(dropdowns[[nm]])) {
      j <- match(col, names(df))
      if (is.na(j)) next
      wb$add_data_validation(sheet = nm, dims = openxlsx2::wb_dims(rows = 2:500, cols = j),
                             type = "list",
                             value = paste0('"', paste(dropdowns[[nm]][[col]], collapse = ","), '"'))
    }
  }
  wb$save(path, overwrite = TRUE)
  invisible(path)
}

read_rulebook_xlsx <- function(path, validate = TRUE) {
  rlang::check_installed("openxlsx2", reason = "to read rulebook spreadsheets.")
  wb <- openxlsx2::wb_load(path)
  want <- names(rulebook_tables(rulebook("x")))
  t <- list()
  blank <- rulebook_tables(rulebook("x"))
  for (nm in want) {
    if (nm %in% wb$sheet_names) {
      df <- openxlsx2::wb_to_df(wb, sheet = nm, col_names = TRUE, skip_empty_rows = TRUE,
                                convert = FALSE)
      df <- as.data.frame(df, stringsAsFactors = FALSE)
      df[] <- lapply(df, function(v) { v[!is.na(v) & !nzchar(trimws(v))] <- NA; v })
      for (col in setdiff(names(blank[[nm]]), names(df))) df[[col]] <- rep(NA, nrow(df))
      t[[nm]] <- df
    } else {
      t[[nm]] <- blank[[nm]]
    }
  }
  # Rows with no key are blank template rows.
  key <- c(plan = "key", zones = "zone", setbacks = "target", bands = "target",
           families = "family", overlays = "id", areas = "id", changes = "target",
           bonuses = "id", entitlements = "id", unmodelled = "rule", variants = "target",
           unit_mix = "name", access_width = "target")
  for (nm in names(key)) t[[nm]] <- t[[nm]][!is.na(t[[nm]][[key[[nm]]]]), , drop = FALSE]
  rb <- tables_to_rulebook(t)
  if (validate) report_validation(validate_rulebook(rb), path)
  rb
}
