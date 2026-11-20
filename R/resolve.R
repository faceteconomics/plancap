# Rule resolution: each site's effective rules. Internal; used by
# build_envelopes(). Order is fixed (PLAN 3.5): zone, then areas (precincts,
# replace), then parameter overlays, in precedence order.

# Apply a set of zone changes to a zone body.
# * `height` and other scalar fields are replaced whole, so a precinct height
#   never inherits the zone's occupiable height or roof allowance;
# * `ratios`, `form`, `density` and `use` are merged field by field;
# * setbacks of the kinds the change replaces are removed, then the change's
#   setbacks are added; `additions` only add.
apply_changes <- function(z, ch, add_only = FALSE) {
  if (is.null(ch)) return(z)
  ch <- to_plain(ch)
  sb <- ch$setbacks
  kinds <- ch$replaces_setbacks %||% unique(vapply(sb %||% list(), `[[`, "", "kind"))
  if (!add_only && length(kinds)) {
    keep <- !vapply(z$setbacks %||% list(), function(s) s$kind %in% kinds, logical(1))
    z$setbacks <- (z$setbacks %||% list())[keep]
  }
  if (length(sb)) z$setbacks <- c(z$setbacks %||% list(), sb)
  for (f in setdiff(names(ch), c("setbacks", "replaces_setbacks", "additions",
                                 "zone_parameters", "totals", "total_group"))) {
    if (f %in% c("ratios", "form", "density", "use") && is.list(z[[f]])) {
      z[[f]] <- utils::modifyList(z[[f]], ch[[f]])
    } else {
      z[f] <- list(ch[[f]])
    }
  }
  if (!is.null(ch$additions)) z <- apply_changes(z, ch$additions, add_only = TRUE)
  z
}

# Effective rules per site. Sites sharing a zone, the same areas and
# sub-areas, the same parameter overlays and the same height-overlay values
# share one parameter set, so rules are resolved once per combination, not
# once per site. Returns each site's `param_id` and the distinct sets.
resolve_sites <- function(prep, rb, site_mods = NULL) {
  s <- sf::st_drop_geometry(prep$sites)
  n <- nrow(s)
  ids <- s$site_id
  areas <- prep$areas
  areas <- areas[areas$share >= 0.5, , drop = FALSE]
  # One row per site and area: a site under both a precinct polygon and one of
  # its sub-precinct polygons takes the sub-precinct.
  areas <- areas[order(areas$site_id, areas$area, is.na(areas$sub_area), -areas$share), , drop = FALSE]
  areas <- areas[!duplicated(areas[c("site_id", "area")]), , drop = FALSE]
  ovs <- prep$overlays
  pov <- names(Filter(function(o) identical(o$type, "parameters") && !isFALSE(o$enabled), rb$overlays))
  pov <- pov[order(vapply(rb$overlays[pov], function(o) o$precedence %||% 0, 0))]
  hov <- names(Filter(function(o) identical(o$type, "height") && !isFALSE(o$enabled), rb$overlays))

  # Per-site key parts.
  area_key <- tapply(paste(areas$area, areas$sub_area, sep = "/"), factor(areas$site_id, levels = ids),
                     paste, collapse = ";")
  pv <- ovs[ovs$overlay %in% pov & ovs$share >= 0.5, , drop = FALSE]
  pov_key <- tapply(pv$overlay, factor(pv$site_id, levels = ids), function(x) paste(sort(unique(x)), collapse = ";"))
  hv <- ovs[ovs$overlay %in% hov & !is.na(ovs$value), , drop = FALSE]
  hv <- hv[order(hv$site_id, hv$overlay, -hv$share), , drop = FALSE]
  hv <- hv[!duplicated(hv[c("site_id", "overlay")]) & hv$share >= 0.5, , drop = FALSE]
  hov_key <- tapply(paste(hv$overlay, hv$value, sep = "="), factor(hv$site_id, levels = ids),
                    paste, collapse = ";")
  mod_key <- rep(NA_character_, n)
  if (!is.null(site_mods) && nrow(site_mods)) {
    mk <- tapply(paste(site_mods$what, site_mods$value, sep = "="), factor(site_mods$site_id, levels = ids),
                 paste, collapse = ";")
    mod_key <- as.vector(mk[ids])
  }
  key <- paste(s$zone_key, area_key[ids], pov_key[ids], hov_key[ids], mod_key, sep = "|")
  key[is.na(s$zone_key)] <- NA

  uk <- unique(stats::na.omit(key))
  bodies <- lapply(uk, function(k) {
    i <- match(k, key)
    resolve_one(s$site_id[i], s$zone_key[i], rb, areas, pov, pv, hov, hv,
                site_mods[site_mods$site_id == s$site_id[i], , drop = FALSE])
  })
  bid <- vapply(bodies, function(b) if (is.null(b)) NA_character_ else rlang::hash(b), "")
  param_id <- bid[match(key, uk)]
  keep <- !is.na(bid) & !duplicated(bid)
  params <- bodies[keep]
  names(params) <- bid[keep]
  list(param_id = param_id, params = params)
}

resolve_one <- function(site_id, zk, rb, areas, pov, pv, hov, hv, mods = NULL) {
  z <- rb$zones[[zk]]
  if (is.null(z)) return(NULL)
  z <- to_plain(z)
  # Areas (precincts) replace.
  for (j in which(areas$site_id == site_id)) {
    ad <- rb$areas[[areas$area[j]]]
    if (!is.null(ad$applies_to_zones) && !zk %in% ad$applies_to_zones) next
    z <- apply_changes(z, ad$parameters)
    z <- apply_changes(z, ad$additions, add_only = TRUE)
    z <- apply_changes(z, ad$zone_parameters[[zk]])
    sa <- areas$sub_area[j]
    sub <- if (!is.na(sa)) ad$sub_areas[[toupper(sa)]] %||% ad$sub_areas[[sa]]
    if (!is.null(sub)) {
      z <- apply_changes(z, sub)
      z <- apply_changes(z, sub$zone_parameters[[zk]])
    }
  }
  # Parameter overlays, in precedence order.
  for (o in intersect(pov, pv$overlay[pv$site_id == site_id])) {
    od <- rb$overlays[[o]]
    if (!is.null(od$applies_to_zones) && !zk %in% od$applies_to_zones) next
    z <- apply_changes(z, od$parameters)
    z <- apply_changes(z, od$additions, add_only = TRUE)
  }
  # Height overlays, in precedence order: the feature covering most of the
  # site. As capacityengine: an override replaces total and occupiable height;
  # a cap lowers total height, and lowers occupiable height only where its
  # (converted) value is lower, so a cap that bites only the roof allowance
  # leaves the storeys as they were; a cap over a zone with no height caps
  # nothing.
  hrows <- hv[hv$site_id == site_id, , drop = FALSE]
  hrows <- hrows[order(vapply(hrows$overlay, function(o) rb$overlays[[o]]$precedence %||% 0, 0)), , drop = FALSE]
  for (j in seq_len(nrow(hrows))) {
    od <- rb$overlays[[hrows$overlay[j]]]
    if (!is.null(od$applies_to_zones) && !zk %in% od$applies_to_zones) next
    z <- apply_height(z, hrows$value[j], convert_height(hrows$value[j], od$height_conversion),
                      od$combine %||% "cap", od$source, rb, zk)
  }
  # Site-specific changes: a height surface covering the whole site (a cap),
  # and a height bonus (added to total and occupiable height).
  for (j in seq_len(NROW(mods))) {
    if (mods$what[j] == "surface_cap") {
      z <- apply_height(z, mods$value[j], mods$value[j], "cap", "height surface", rb, zk)
    } else if (mods$what[j] == "height_add" && !is.null(z$height)) {
      h <- z$height
      if (is.numeric(h$value)) h$value <- h$value + mods$value[j]
      occ <- h$occupiable %||% (if (is.numeric(h$value)) h$value - mods$value[j] - (h$roof_allowance %||% 0))
      if (!is.null(occ)) h$occupiable <- occ + mods$value[j]
      h$zone_storey_height <- h$zone_storey_height %||% zone_storey_height(rb, z, zk)
      h$storeys <- NULL
      z$height <- h
    }
  }
  z
}

# A zone's storey height is its own: stated height over stated storeys, or its
# storey_height, or the default. It does not change when an overlay moves the
# site's height (capacityengine item 245).
zone_storey_height <- function(rb, z, zone_key) {
  base <- rb$zones[[zone_key]] %||% z
  storey_height_of(base, rb$defaults$storey_height %||% 3)
}

# A zone's own storey height (capacityengine item 245): stated, or its
# occupiable height over its stated storeys, or its occupiable height divided
# into as many default-height storeys as fit (20 m: six of 3.33 m), or the
# default where the zone states no height.
storey_height_of <- function(z, default) {
  if (!is.null(z$storey_height)) return(z$storey_height)
  h <- z$height
  occ <- h$occupiable %||% (if (is.numeric(h$value)) h$value - (h$roof_allowance %||% 0))
  if (!is.null(occ) && !is.na(occ)) {
    if (!is.null(h$storeys) && h$storeys > 0) return(occ / h$storeys)
    if (occ >= default) return(occ / floor(occ / default))
  }
  default
}

# Variants a parameter set offers: none means one, "standard".
param_variants <- function(z) {
  v <- unique(c(names(z$variants), unlist(lapply(z$setbacks, `[[`, "variant"))))
  if (!length(v)) "standard" else v
}

# Apply one height limit (total height and its occupiable part) to a zone body.
apply_height <- function(z, total, occupiable, combine, source, rb, zk) {
  h <- z$height %||% list()
  cur_t <- if (is.numeric(h$value)) h$value else NA_real_
  cur_o <- h$occupiable %||% (if (!is.na(cur_t)) cur_t - (h$roof_allowance %||% 0) else NA_real_)
  zsh <- h$zone_storey_height %||% zone_storey_height(rb, z, zk)
  if (combine == "replace") {
    z$height <- compact(list(value = total, occupiable = occupiable, source = source %||% h$source,
                             zone_storey_height = zsh))
  } else if (combine == "cap") {
    if (is.na(cur_t)) return(z)            # a cap over no height caps nothing
    new_t <- min(cur_t, total)
    new_o <- min(cur_o, occupiable)
    if (new_t < cur_t || new_o < cur_o) {
      h$value <- new_t
      if (new_o < cur_o) {
        h$occupiable <- new_o
        h$storeys <- NULL
        h$zone_storey_height <- zsh
      } else {
        h$occupiable <- cur_o
      }
      z$height <- h
    }
  } else if (combine == "floor") {
    if (is.na(cur_t) || total > cur_t) {
      z$height <- compact(list(value = total, occupiable = max(occupiable, cur_o, na.rm = TRUE),
                               source = source, zone_storey_height = zsh))
    }
  }
  z
}

# A mapped height is total height; a conversion table gives its occupiable
# part (Auckland's Height Variation Control: 13 m total is 11 m occupiable).
convert_height <- function(total, conv) {
  if (is.null(conv) || is.na(total)) return(total)
  if (is.data.frame(conv$table)) {
    conv$table <- lapply(seq_len(nrow(conv$table)), function(i) as.list(conv$table[i, c("total", "occupiable")]))
  }
  if (!is.null(conv$passthrough_below) && total <= conv$passthrough_below) return(total)
  if (!is.null(conv$passthrough_above) && total > conv$passthrough_above) return(total)
  tt <- vapply(conv$table, function(r) r$total, 0)
  oo <- vapply(conv$table, function(r) r$occupiable, 0)
  hit <- which(abs(tt - total) < 1e-9)
  if (length(hit)) return(oo[hit[1]])
  switch(conv$between %||% "passthrough",
         interpolate = stats::approx(tt, oo, xout = total, rule = 2)$y,
         snap_nearest = oo[which.min(abs(tt - total))],
         total)
}
