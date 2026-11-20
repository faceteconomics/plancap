# The plan geometry step: everything about sites that depends on the zoning,
# overlay and area layers, but not on rule values. Internal; called by
# prepare_sites().

plan_geometry <- function(pg, zoning, rulebook, layers = list(), zone_field = "zone",
                          inputs = list(), morphology = list()) {
  m <- morphology_settings(rulebook, morphology)
  sites <- pg$sites
  crs <- sf::st_crs(sites)
  check_projected(zoning)
  if (sf::st_crs(zoning) != crs) zoning <- sf::st_transform(zoning, crs)
  if (!zone_field %in% names(zoning)) {
    cli::cli_abort("The zoning layer has no {.field {zone_field}} column.")
  }
  report <- list()

  # ---- Zone codes to zone keys -------------------------------------------------
  codes <- as.character(zoning[[zone_field]])
  zmap <- unlist(rulebook$zone_map %||% list())
  zoning$zone_code <- codes
  zoning$zone_key <- unname(zmap[codes])
  unmapped <- sort(unique(codes[is.na(zoning$zone_key)]))
  if (length(unmapped)) report$unmapped_zone_codes <- unmapped
  zg <- as_geos(zoning)

  # ---- Split sites by zone -------------------------------------------------------
  sg <- as_geos(sites)
  ov <- overlap_table(sg, zg, min_area = 0)
  ov$key <- ifelse(is.na(zoning$zone_key[ov$feature]), paste0("?", codes[ov$feature]),
                   zoning$zone_key[ov$feature])
  # Area by site and zone (several features of one zone count together).
  agg <- stats::aggregate(area ~ site + key, data = ov, FUN = sum)
  agg <- agg[order(agg$site, -agg$area), ]
  site_area <- geos::geos_area(sg)
  zoned_area <- tapply(agg$area, agg$site, sum)
  # Pieces smaller than the sliver threshold join the largest piece of the site.
  big <- agg$area >= m$min_sliver_area
  n_big <- tapply(big, agg$site, sum)
  multi <- sort(as.integer(names(n_big)[n_big > 1]))
  dominant <- agg[!duplicated(agg$site), ]

  sites$zone_key <- NA_character_
  sites$zone_code <- NA_character_
  sites$parent_id <- sites$site_id
  sites$zone_share <- 0
  dk <- dominant$key
  sites$zone_key[dominant$site] <- ifelse(startsWith(dk, "?"), NA_character_, dk)
  sites$zone_code[dominant$site] <- ifelse(startsWith(dk, "?"), substring(dk, 2),
                                           names(zmap)[match(dk, zmap)])
  sites$zone_share[dominant$site] <- dominant$area / site_area[dominant$site]
  unzoned <- setdiff(seq_len(nrow(sites)), agg$site)

  segments <- pg$segments
  segments$parent_id <- segments$site_id
  segments$tags <- segments$tags
  legs <- pg$access_legs

  if (length(multi)) {
    parts <- split_parts(sg, zg, ov, agg, multi, m$min_sliver_area)
    parent_ids <- sites$site_id[parts$site]
    part_sf <- sf::st_sf(site_id = paste0(parent_ids, "-z", parts$n),
                         geometry = sf::st_as_sfc(parts$geom))
    sf::st_crs(part_sf) <- crs
    ppg <- parcel_geometry(part_sf, roads = inputs$roads, water = inputs$water,
                           centrelines = inputs$centrelines, width_field = inputs$width_field %||% "width_m",
                           rulebook = rulebook, morphology = morphology)
    if (!is.null(inputs$dem)) ppg <- attach_terrain(ppg, inputs$dem)
    new_sites <- ppg$sites
    if ("parcel_ids" %in% names(sites)) new_sites$parcel_ids <- sites$parcel_ids[parts$site]
    new_sites$zone_key <- ifelse(startsWith(parts$key, "?"), NA_character_, parts$key)
    new_sites$zone_code <- ifelse(startsWith(parts$key, "?"), substring(parts$key, 2),
                                  names(zmap)[match(parts$key, zmap)])
    new_sites$parent_id <- parent_ids
    new_sites$zone_share <- 1
    # Boundaries between two pieces of one landholding are zone boundaries.
    pseg <- ppg$segments
    pseg$parent_id <- sub("-z[0-9]+$", "", pseg$site_id)
    parent_ring <- geos::geos_boundary(sg[match(pseg$parent_id, sites$site_id)])
    on_parent <- shared_length_pairwise(as_geos(pseg), parent_ring, 0.01)
    internal <- on_parent < 0.5 * pseg$length
    pseg$tags[internal] <- paste0(pseg$tags[internal], "zone_boundary|")
    sites <- bind_sf(sites[-multi, ], new_sites)
    segments <- bind_sf(segments[!segments$site_id %in% sites_ids_of(pg$sites, multi), ], pseg)
    legs <- legs[!legs$site_id %in% sites_ids_of(pg$sites, multi), ]
    if (nrow(ppg$access_legs)) legs <- if (nrow(legs)) rbind(legs, ppg$access_legs) else ppg$access_legs
    report$sites_split <- length(multi)
  }
  sites$flag[is.na(sites$zone_key) & sites$flag == "ok"] <- "no_zone"
  if (length(unzoned)) report$unzoned_sites <- length(unzoned)

  # ---- Zone across each boundary -------------------------------------------------
  segments <- adjacency(segments, sites, zoning, zg, rulebook, m)
  report$adjacency_unresolved <- sum(is.na(segments$adjacent_zone_code))

  # ---- Overlays, areas and distances -----------------------------------------------
  sg <- as_geos(sites)
  ov_tab <- membership(sites, sg, rulebook$overlays, layers, crs, kind = "overlay")
  ar_tab <- membership(sites, sg, rulebook$areas, layers, crs, kind = "area")
  report$overlay_layers_missing <- attr(ov_tab, "missing")
  report$area_layers_missing <- attr(ar_tab, "missing")
  dist <- distances(sites, sg, rulebook, layers, crs)
  report$distance_layers_missing <- attr(dist, "missing")

  list(sites = sites, segments = segments, access_legs = legs, overlays = ov_tab,
       areas = ar_tab, distances = dist, report = compact(report))
}

sites_ids_of <- function(sites, idx) sites$site_id[idx]

# rbind two sf tables, adding any column one lacks as NA, in a's column order.
bind_sf <- function(a, b) {
  for (cc in setdiff(names(a), names(b))) b[[cc]] <- if (is.list(a[[cc]])) list(NULL) else NA
  for (cc in setdiff(names(b), names(a))) a[[cc]] <- if (is.list(b[[cc]])) list(NULL) else NA
  b <- b[, names(a)]
  rbind(a, b)
}

# Shared length between segment i and geometry i (paired, not all-by-all).
shared_length_pairwise <- function(seg_geom, other, tolerance) {
  geos::geos_length(geos::geos_intersection(seg_geom, geos::geos_buffer(other, tolerance)))
}

# The pieces of sites that more than one zone covers: one piece per site and
# zone, slivers merged into the site's largest piece, and any unzoned remainder
# kept as its own piece (flag, don't drop).
split_parts <- function(sg, zg, ov, agg, multi, min_sliver) {
  rows <- ov[ov$site %in% multi, ]
  inter <- geos::geos_intersection(sg[rows$site], zg[rows$feature])
  key_id <- paste(rows$site, rows$key, sep = "\r")
  u <- unique(key_id)
  pieces <- geos::geos_unary_union(geos::geos_make_collection(
    inter[order(match(key_id, u))], feature_id = sort(match(key_id, u))))
  p_site <- as.integer(sub("\r.*", "", u))
  p_key <- sub("^[^\r]*\r", "", u)
  p_area <- geos::geos_area(pieces)
  # Unzoned remainder of each split site.
  zoned <- geos::geos_unary_union(geos::geos_make_collection(
    pieces[order(p_site)], feature_id = match(sort(p_site), multi)))
  rest <- geos::geos_difference(sg[multi], zoned)
  rest_area <- geos::geos_area(rest)
  if (any(rest_area >= min_sliver)) {
    k <- which(rest_area >= min_sliver)
    pieces <- c(pieces, rest[k])
    p_site <- c(p_site, multi[k])
    p_key <- c(p_key, rep("?", length(k)))
    p_area <- c(p_area, rest_area[k])
  }
  # Merge slivers into the largest piece of their site.
  o <- order(p_site, -p_area)
  pieces <- pieces[o]
  p_site <- p_site[o]
  p_key <- p_key[o]
  p_area <- p_area[o]
  largest <- !duplicated(p_site)
  sliver <- p_area < min_sliver & !largest
  if (any(sliver)) {
    tgt <- match(p_site[sliver], p_site[largest])
    li <- which(largest)
    for (j in unique(tgt)) {
      add <- which(sliver)[tgt == j]
      pieces[li[j]] <- geos::geos_unary_union(geos::geos_make_collection(c(pieces[li[j]], pieces[add])))
    }
    keep <- !sliver
    pieces <- pieces[keep]
    p_site <- p_site[keep]
    p_key <- p_key[keep]
  }
  # An intersection can return a collection of a polygon and stray lines where
  # boundaries touch; a zero buffer keeps the polygonal part only.
  list(geom = geos::geos_buffer(geos::geos_make_valid(pieces), 0), site = p_site, key = p_key,
       n = stats::ave(p_site, p_site, FUN = seq_along))
}

# Which zone lies across each boundary: probe outward from the midpoint, far
# enough across a road to clear the carriageway. The whole zoning layer is
# used, open space included: it carries no capacity but is exactly what many
# rules name.
adjacency <- function(segments, sites, zoning, zg, rulebook, m) {
  n <- nrow(segments)
  b <- segments$outward_bearing * pi / 180
  mx <- (segments$x0 + segments$x1) / 2
  my <- (segments$y0 + segments$y1) / 2
  is_road <- segments$boundary_class == "road"
  d <- ifelse(is_road, m$road_probe_distance, m$boundary_probe_distance)
  # Clip the lookup geometry to the working extent: one zoning feature can hold
  # hundreds of thousands of vertices, and no spatial index saves a
  # point-in-polygon test against all of it.
  bb <- sf::st_bbox(segments)
  pad <- max(m$road_probe_distance, m$boundary_probe_distance) + 1
  box <- geos::as_geos_geometry(sf::st_as_sfc(sf::st_bbox(
    c(xmin = bb[["xmin"]] - pad, ymin = bb[["ymin"]] - pad,
      xmax = bb[["xmax"]] + pad, ymax = bb[["ymax"]] + pad), crs = sf::st_crs(segments))))
  near <- lengths(geos::geos_intersects_matrix(zg, box)) > 0
  lookup <- geos::geos_intersection(zg[near], box)
  idx_near <- which(near)
  pts <- points_like(mx + sin(b) * d, my + cos(b) * d, lookup)
  hit <- first_match(geos::geos_intersects_matrix(pts, lookup))
  feat <- idx_near[hit]
  segments$adjacent_zone_code <- zoning$zone_code[feat]
  segments$adjacent_zone_key <- zoning$zone_key[feat]

  # Families each adjacent zone belongs to, as a |-delimited token string so
  # rules test set membership with a single grepl.
  fams <- rulebook$zone_families %||% list()
  keys <- unique(stats::na.omit(segments$adjacent_zone_key))
  tok <- vapply(keys, function(k) {
    f <- names(fams)[vapply(fams, function(v) k %in% v, logical(1))]
    paste0("|", paste(c(k, f), collapse = "|"), "|")
  }, "")
  segments$adjacent_tokens <- unname(tok[segments$adjacent_zone_key])

  # Reserve boundaries: across the boundary is a zone of a reserve family.
  # Recorded as a tag; the boundary keeps its side or rear class.
  res_zones <- unique(unlist(fams[intersect(m$reserve_families, names(fams))]))
  is_res <- !is_road & segments$adjacent_zone_key %in% res_zones
  segments$tags[is_res] <- paste0(segments$tags[is_res], "reserve|")
  # Contiguous area of the reserve across the boundary, for rules that depend
  # on the size of the open space (component labelling: a commonly zoned
  # multi-site reserve counts as one).
  segments$adjacent_area <- NA_real_
  if (any(is_res)) {
    ri <- which(zoning$zone_key %in% res_zones)
    rg <- zg[ri]
    comp <- components(length(ri), geos::geos_intersects_matrix(rg, rg))
    comp_area <- tapply(geos::geos_area(rg), comp, sum)
    w <- which(is_res)
    f <- match(feat[w], ri)
    segments$adjacent_area[w] <- as.vector(comp_area[comp[f]])
  }
  segments
}

# Site membership of overlays or areas: one row per site and overlapping
# feature, with the share of the site covered and the feature's value.
membership <- function(sites, sg, defs, layers, crs, kind) {
  out <- list()
  missing <- character()
  for (id in names(defs)) {
    d <- defs[[id]]
    lyr <- layers[[d$layer]]
    if (is.null(lyr)) {
      missing <- c(missing, d$layer)
      next
    }
    if (!inherits(lyr, "sf")) next          # rasters are sampled by the engine
    if (sf::st_crs(lyr) != crs) lyr <- sf::st_transform(lyr, crs)
    for (f in names(d$filter)) {
      if (!f %in% names(lyr)) cli::cli_abort("Layer {.val {d$layer}} has no {.field {f}} column for {kind} {.val {id}}'s filter.")
      lyr <- lyr[as.character(lyr[[f]]) %in% as.character(d$filter[[f]]), ]
    }
    if (!nrow(lyr)) next
    fg <- as_geos(lyr)
    if (!is.null(d$buffer)) {
      r <- if (is.numeric(d$buffer)) d$buffer else as.numeric(lyr[[d$buffer]])
      fg <- geos::geos_buffer(fg, r)
    } else if (!all(geos::geos_type(fg) %in% c("polygon", "multipolygon"))) {
      fg <- geos::geos_buffer(fg, 0.01)
    }
    tab <- overlap_table(sg, fg)
    if (!nrow(tab)) next
    val <- if (!is.null(d[["value_field"]])) {
      v <- lyr[[d[["value_field"]]]][tab$feature]
      if (!is.null(d[["value_map"]])) unlist(d[["value_map"]])[as.character(v)] else as.numeric(v)
    } else if (is.numeric(d[["value"]])) d[["value"]] else NA_real_
    out[[length(out) + 1]] <- data.frame(
      site_id = sites$site_id[tab$site], id = id, feature = tab$feature,
      share = tab$area / geos::geos_area(sg[tab$site]), value = as.numeric(val),
      sub_area = if (kind == "area" && !is.null(d$sub_area_field)) as.character(lyr[[d$sub_area_field]][tab$feature]) else NA_character_,
      stringsAsFactors = FALSE)
  }
  res <- if (length(out)) do.call(rbind, out) else
    data.frame(site_id = character(), id = character(), feature = integer(), share = numeric(),
               value = numeric(), sub_area = character())
  names(res)[2] <- kind
  attr(res, "missing") <- unique(missing)
  res
}

# Distance from each site to the nearest feature of every layer a rule's
# distance condition names.
distances <- function(sites, sg, rulebook, layers, crs) {
  wanted <- unique(unlist(lapply(c(rulebook$zones, rulebook$bonuses, rulebook$entitlements),
                                 function(x) find_key(x, "distance_to"))))
  out <- list()
  missing <- character()
  for (l in wanted) {
    lyr <- layers[[l]]
    if (is.null(lyr)) {
      missing <- c(missing, l)
      next
    }
    if (sf::st_crs(lyr) != crs) lyr <- sf::st_transform(lyr, crs)
    fg <- as_geos(lyr)
    near <- geos::geos_nearest(sg, fg)
    out[[l]] <- data.frame(site_id = sites$site_id, layer = l,
                           distance = geos::geos_distance(sg, fg[near]))
  }
  res <- if (length(out)) do.call(rbind, out) else
    data.frame(site_id = character(), layer = character(), distance = numeric())
  rownames(res) <- NULL
  attr(res, "missing") <- unique(missing)
  res
}

find_key <- function(x, key) {
  if (!is.list(x)) return(NULL)
  c(if (!is.null(names(x)) && key %in% names(x)) x[[key]],
    unlist(lapply(x, find_key, key = key), use.names = FALSE))
}
