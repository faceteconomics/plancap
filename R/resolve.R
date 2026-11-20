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
resolve_sites <- function(prep, rb) {
  s <- sf::st_drop_geometry(prep$sites)
  n <- nrow(s)
  ids <- s$site_id
  areas <- prep$areas
  areas <- areas[areas$share >= 0.5, , drop = FALSE]
  areas <- areas[order(areas$site_id, -areas$share), , drop = FALSE]
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
  key <- paste(s$zone_key, area_key[ids], pov_key[ids], hov_key[ids], sep = "|")
  key[is.na(s$zone_key)] <- NA

  uk <- unique(stats::na.omit(key))
  bodies <- lapply(uk, function(k) {
    i <- match(k, key)
    resolve_one(s$site_id[i], s$zone_key[i], rb, areas, pov, pv, hov, hv)
  })
  bid <- vapply(bodies, function(b) if (is.null(b)) NA_character_ else rlang::hash(b), "")
  param_id <- bid[match(key, uk)]
  keep <- !is.na(bid) & !duplicated(bid)
  params <- bodies[keep]
  names(params) <- bid[keep]
  list(param_id = param_id, params = params)
}

resolve_one <- function(site_id, zk, rb, areas, pov, pv, hov, hv) {
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
  # Height overlays: the feature covering most of the site (partial coverage
  # is resolved in a later stage of the engine).
  for (j in which(hv$site_id == site_id)) {
    od <- rb$overlays[[hv$overlay[j]]]
    if (!is.null(od$applies_to_zones) && !zk %in% od$applies_to_zones) next
    v <- hv$value[j]
    h <- z$height %||% list()
    cur <- if (is.numeric(h$value)) h$value else NA_real_
    new <- switch(od$combine %||% "cap",
                  cap = if (is.na(cur)) v else min(cur, v),
                  replace = v, floor = max(cur, v, na.rm = TRUE), cur)
    if (!identical(new, cur)) {
      # A mapped height is total height; the zone's roof allowance still applies.
      ra <- h$roof_allowance %||% 0
      z$height <- compact(list(value = new, occupiable = new - ra, roof_allowance = h$roof_allowance,
                               source = od$source %||% h$source,
                               zone_storey_height = zone_storey_height(rb, z, zk)))
    }
  }
  z
}

# A zone's storey height is its own: stated height over stated storeys, or its
# storey_height, or the default. It does not change when an overlay moves the
# site's height (capacityengine item 245).
zone_storey_height <- function(rb, z, zone_key) {
  base <- rb$zones[[zone_key]] %||% z
  h <- base$height
  occ <- h$occupiable %||% (if (is.numeric(h$value)) h$value - (h$roof_allowance %||% 0))
  if (!is.null(h$storeys) && is.numeric(occ)) return(occ / h$storeys)
  base$storey_height %||% rb$defaults$storey_height %||% 3
}

# Variants a parameter set offers: none means one, "standard".
param_variants <- function(z) {
  v <- unique(c(names(z$variants), unlist(lapply(z$setbacks, `[[`, "variant"))))
  if (!length(v)) "standard" else v
}
