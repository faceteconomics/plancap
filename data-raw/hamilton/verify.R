# Verify saved Hamilton runs (data-raw/hamilton/run.R) against the rulebook,
# independently of the engine's own rule resolution: each site's rules are
# rebuilt here from its zone and the overlay layers it lies in, and every
# result is checked against the bounds those rules set.
#   Rscript data-raw/hamilton/verify.R              # every extract with a run.rds, not the city
#   Rscript data-raw/hamilton/verify.R city         # one by name
setwd("D:/Projects_cl/plancap")
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
root <- "data-raw/cache/hamilton"
args <- commandArgs(trailingOnly = TRUE)
ex <- c("peacocke", "ruakura", "frankton", "thebase", "terapa", "university", "city")
dirs <- c(claudelands = root, setNames(file.path(root, ex), ex))
dirs <- dirs[file.exists(file.path(dirs, "run.rds"))]
dirs <- if (length(args)) dirs[args] else dirs[names(dirs) != "city"]

`%||%` <- function(a, b) if (is.null(a)) b else a
merge_rules <- function(z, p) {
  for (k in names(p)) z[[k]] <- if (is.list(p[[k]]) && is.list(z[[k]]) && !is.null(names(p[[k]]))) merge_rules(z[[k]], p[[k]]) else p[[k]]
  z
}

verify_run <- function(nm, d) {
  x <- readRDS(file.path(d, "run.rds"))
  cap <- x$cap; sc <- x$sc; rb <- cap$rulebook
  s <- cap$sites
  ga <- as.numeric(sf::st_area(s))
  # Share of each site inside a layer (optionally buffered), measured here.
  share <- function(lyr, buf = 0) {
    out <- numeric(nrow(s))
    if (is.null(lyr) || !nrow(lyr)) return(out)
    g <- sf::st_union(sf::st_make_valid(sf::st_geometry(lyr)))
    if (buf > 0) g <- sf::st_buffer(g, buf)
    hit <- which(lengths(sf::st_intersects(s, g)) > 0)
    if (!length(hit)) return(out)
    xi <- suppressWarnings(sf::st_intersection(s[hit, "site_id"], sf::st_sf(geometry = g)))
    a <- tapply(as.numeric(sf::st_area(xi)), xi$site_id, sum)
    i <- match(names(a), s$site_id)
    out[i] <- a / ga[i]
    pmin(out, 1)
  }
  ovs <- rb$overlays
  sh <- lapply(ovs, function(o) share(sc$layers[[o$layer]], as.numeric(o$buffer %||% 0)))
  # Exclusions together, for the removed area.
  ex_ids <- names(Filter(function(o) identical(o$type, "exclusion") && !isFALSE(o$enabled), ovs))
  ex_geo <- do.call(c, lapply(ex_ids, function(o) {
    l <- sc$layers[[ovs[[o]]$layer]]
    if (is.null(l) || !nrow(l)) return(NULL)
    g <- sf::st_geometry(sf::st_make_valid(l))
    b <- as.numeric(ovs[[o]]$buffer %||% 0)
    if (b > 0) sf::st_buffer(g, b) else g
  }))
  ex_share <- share(if (length(ex_geo)) sf::st_sf(geometry = ex_geo) else NULL)
  in_area <- share(sc$layers$precincts) >= 0.5

  df <- sf::st_drop_geometry(s)
  n <- nrow(df)
  fails <- list()
  fail <- function(check, i, detail) if (length(i)) fails[[check]] <<- data.frame(check = check, site_id = df$site_id[i], zone = df$zone_key[i], detail = detail[seq_along(i)])
  bound <- data.frame(height = rep(NA_real_, n), storeys = NA_real_, coverage = NA_real_, landscaping = NA_real_,
                      far = NA_real_, maxd = NA_real_, minor = NA_real_, sapd = NA_real_, res = NA, bus = NA, method = NA_character_)
  pov <- names(Filter(function(o) identical(o$type, "parameters") && !isFALSE(o$enabled), ovs))
  pov <- pov[order(vapply(ovs[pov], function(o) o$precedence %||% 0, 0))]
  for (i in seq_len(n)) {
    zk <- df$zone_key[i]
    z <- rb$zones[[zk]]
    if (is.null(z)) next
    for (o in pov) if (sh[[o]][i] >= 0.5 && (is.null(ovs[[o]]$applies_to_zones) || zk %in% ovs[[o]]$applies_to_zones))
      z <- merge_rules(z, ovs[[o]]$parameters)
    h <- z$height
    st_h <- if (!is.null(h$storeys) && is.numeric(rb$zones[[zk]]$height$value) && !is.null(rb$zones[[zk]]$height$storeys))
      rb$zones[[zk]]$height$occupiable %||% rb$zones[[zk]]$height$value else NULL
    zsh <- if (!is.null(rb$zones[[zk]]$height$storeys)) (rb$zones[[zk]]$height$occupiable %||% rb$zones[[zk]]$height$value) / rb$zones[[zk]]$height$storeys else
      rb$zones[[zk]]$height$storey_height %||% rb$zones[[zk]]$storey_height %||% rb$defaults$storey_height %||% 3
    occ <- h$occupiable %||% h$value
    bound$height[i] <- h$value %||% NA
    bound$storeys[i] <- if (!is.null(h$storeys)) h$storeys else if (is.numeric(occ)) floor(occ / zsh + 1e-9) else NA
    bound$coverage[i] <- z$ratios$coverage_max$value %||% NA
    bound$landscaping[i] <- z$ratios$landscaping_min$value %||% NA
    bound$far[i] <- z$ratios$far_max$value %||% NA
    bound$maxd[i] <- z$density$max_dwellings_per_site %||% NA
    bound$minor[i] <- z$density$minor_dwellings_per_site %||% NA
    bound$sapd[i] <- z$density$site_area_per_dwelling %||% NA
    bound$res[i] <- isTRUE(z$use$residential); bound$bus[i] <- isTRUE(z$use$business)
    bound$method[i] <- z$method %||% "volumetric"
  }
  eps <- 1e-6
  ok_rules <- !is.na(df$zone_key) & !in_area
  # Height and storeys.
  i <- which(ok_rules & df$storeys > 0 & !is.na(bound$storeys) & df$storeys_allowed > bound$storeys + eps)
  fail("storeys allowed within the rules' storeys", i, sprintf("%g > %g", df$storeys_allowed[i], bound$storeys[i]))
  i <- which(ok_rules & df$storeys > df$storeys_allowed + eps)
  fail("storeys built within storeys allowed", i, sprintf("%g > %g", df$storeys[i], df$storeys_allowed[i]))
  i <- which(ok_rules & !is.na(df$height) & !is.na(bound$height) & df$height > bound$height + eps)
  fail("height within the limit", i, sprintf("%.2f > %.2f", df$height[i], bound$height[i]))
  under <- which(ok_rules & df$storeys > 0 & !is.na(bound$storeys) & df$storeys_allowed < bound$storeys - eps)
  # Ground and floor area.
  i <- which(ok_rules & !is.na(bound$coverage) & df$footprint > bound$coverage * df$net_area + 0.01)
  fail("coverage", i, sprintf("%.1f > %.2f x %.1f", df$footprint[i], bound$coverage[i], df$net_area[i]))
  i <- which(ok_rules & !is.na(bound$landscaping) & df$footprint > (1 - bound$landscaping) * df$net_area + 0.01)
  fail("landscaping", i, sprintf("%.1f > (1 - %.2f) x %.1f", df$footprint[i], bound$landscaping[i], df$net_area[i]))
  # A floor area ratio and a density are measured on the land the rulebook
  # names (morphology far_area, density_area: Hamilton uses net site area).
  # The "on net site area" line reports what a whole-site basis would add.
  net_basis <- function(k) identical(rb$morphology[[k]], "net")
  far_land <- if (net_basis("far_area")) df$net_area else df$area
  i <- which(ok_rules & !is.na(bound$far) & df$floor_area > bound$far * far_land + 0.01)
  fail("floor area ratio", i, sprintf("%.1f > %.2f x %.1f", df$floor_area[i], bound$far[i], far_land[i]))
  far_net <- which(ok_rules & !is.na(bound$far) & df$floor_area > bound$far * df$net_area + 0.01)
  i <- which(df$floor_area > df$footprint * pmax(df$storeys, 0) + 0.01)
  fail("floor area within footprint x storeys", i, sprintf("%.1f > %.1f x %d", df$floor_area[i], df$footprint[i], df$storeys[i]))
  # Dwellings.
  i <- which(ok_rules & !is.na(bound$maxd) & df$dwellings > bound$maxd)
  fail("dwellings per site", i, sprintf("%d > %g", df$dwellings[i], bound$maxd[i]))
  dens <- ok_rules & !is.na(bound$sapd) & df$path %in% c("density", "hybrid_density")
  land <- pmax(0, (if (net_basis("density_area")) df$net_area else df$area) - df$removed_area)
  i <- which(dens & df$dwellings > floor(land / bound$sapd + 1e-9))
  fail("site area per dwelling", i, sprintf("%d > %.1f / %g", df$dwellings[i], land[i], bound$sapd[i]))
  net_land <- pmax(0, df$net_area - df$removed_area)
  dens_net <- which(dens & df$dwellings > pmax(1, floor(net_land / bound$sapd + 1e-9)))
  i <- which(df$minor_dwellings > 0 & (is.na(bound$minor) | df$minor_dwellings > bound$minor * df$dwellings))
  fail("minor dwellings", i, sprintf("%d minor, %d dwellings, %g per site", df$minor_dwellings[i], df$dwellings[i], bound$minor[i]))
  # Uses and methods.
  i <- which(!is.na(df$zone_key) & !bound$res & (df$residential_floor_area > eps | df$dwellings > 0))
  fail("no dwellings where residential is not provided for", i, sprintf("%.1f m2, %d", df$residential_floor_area[i], df$dwellings[i]))
  i <- which(!is.na(df$zone_key) & !bound$bus & df$business_floor_area > eps)
  fail("no business floor where business is not provided for", i, sprintf("%.1f m2", df$business_floor_area[i]))
  i <- which(bound$method %in% "none" & df$floor_area > eps)
  fail("nothing in method-none zones", i, sprintf("%.1f m2", df$floor_area[i]))
  # Exclusions, measured against the layers here.
  i <- which(ex_share >= 0.999 & df$floor_area > eps)
  fail("nothing on sites wholly excluded", i, sprintf("%.1f m2, %.3f excluded", df$floor_area[i], ex_share[i]))
  # Zones with no capacity are not clipped. Access legs come off the ground
  # before exclusions, so an exclusion over a leg removes up to the leg less.
  diff_rm <- df$removed_area - ex_share * ga
  tol <- pmax(1, 0.01 * ga)
  i <- which(!is.na(df$zone_key) & !bound$method %in% "none" &
               (diff_rm > tol | -diff_rm > (df$area - df$net_area) + tol))
  fail("removed area matches the exclusion layers", i, sprintf("removed %.1f, layers %.1f of %.1f", df$removed_area[i], ex_share[i] * ga[i], ga[i]))

  res <- do.call(rbind, fails)
  checks <- c("storeys allowed within the rules' storeys", "storeys built within storeys allowed", "height within the limit",
              "coverage", "landscaping", "floor area ratio", "floor area within footprint x storeys", "dwellings per site",
              "site area per dwelling", "minor dwellings", "no dwellings where residential is not provided for",
              "no business floor where business is not provided for", "nothing in method-none zones",
              "nothing on sites wholly excluded", "removed area matches the exclusion layers")
  tab <- data.frame(extract = nm, check = checks,
                    failures = vapply(checks, function(k) if (is.null(fails[[k]])) 0L else nrow(fails[[k]]), 0L), row.names = NULL)
  cat("\n==== ", nm, ": ", n, " sites, ", sum(ok_rules), " checked against zone + overlay rules (", sum(in_area, na.rm = TRUE),
      " in precincts left out of the rule bounds)\n", sep = "")
  print(tab[, -1], row.names = FALSE)
  if (length(under)) cat(length(under), "sites with fewer storeys allowed than the rules' storeys (height overlays or rounding):",
                         paste(utils::head(unique(paste(df$zone_key[under], df$storeys_allowed[under], "of", bound$storeys[under])), 8), collapse = "; "), "\n")
  cat(sprintf("On net site area (access legs out): %d sites over the floor area ratio (%.0f m2), %d over the density (%d dwellings)\n",
              length(far_net), sum(df$floor_area[far_net] - bound$far[far_net] * df$net_area[far_net]), length(dens_net),
              sum(df$dwellings[dens_net] - pmax(1, floor(net_land[dens_net] / bound$sapd[dens_net] + 1e-9)))))
  if (!is.null(res)) { cat("First failures:\n"); print(utils::head(res[order(res$check), ], 20), row.names = FALSE) }
  # Overlay effects, from the layers measured here.
  hha <- sh$heritage_area >= 0.5 & df$zone_key %in% ovs$heritage_area$applies_to_zones
  cat(sprintf("Heritage areas: %d residential sites; max dwellings %s, max storeys %s, minor dwellings %d\n", sum(hha),
              if (any(hha)) max(df$dwellings[hha]) else NA, if (any(hha)) max(df$storeys[hha]) else NA,
              sum(df$minor_dwellings[hha])))
  for (o in ex_ids) cat(sprintf("%s: %d sites touched, %.0f m2 of site inside, %d sites wholly inside\n", o,
                                sum(sh[[o]] > 0), sum(sh[[o]] * ga), sum(sh[[o]] >= 0.999)))
  # Achieved intensity by zone, for a sense check.
  z <- stats::aggregate(cbind(area, floor_area, dwellings, minor_dwellings) ~ zone_key, df, sum)
  z$far <- round(z$floor_area / z$area, 2)
  z$dw_per_ha <- round(z$dwellings / z$area * 1e4, 1)
  print(z[z$floor_area > 0, c("zone_key", "area", "far", "dw_per_ha")], row.names = FALSE)
  invisible(list(tab = tab, fails = res))
}

all <- lapply(names(dirs), function(nm) verify_run(nm, dirs[[nm]]))
tot <- do.call(rbind, lapply(all, `[[`, "tab"))
cat("\n==== All extracts: failures by check\n")
print(stats::aggregate(failures ~ check, tot, sum), row.names = FALSE)
