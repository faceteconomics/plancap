# Test scenario comparison on a Hamilton extract (Claudelands by default:
# the extract with every H3 overlay). Each change is one the answer to which
# is known in advance, so the comparison can be checked, not just run:
#   - the same scenario again (no change anywhere);
#   - PC14's High Flood Hazard Area switched off (rules; only flood sites gain);
#   - Historic Heritage Areas switched off (rules; only heritage sites change);
#   - General Residential rezoned to Medium Density (zoning);
#   - all of these plus half the heritage area polygons dropped (rules,
#     zoning and layers at once, for the attribution).
# Every scenario is also run in full from scratch, to check the incremental
# runs equal full runs site by site.
#   Rscript data-raw/hamilton/compare.R            # Claudelands
#   Rscript data-raw/hamilton/compare.R frankton   # another extract
setwd("D:/Projects_cl/plancap")
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
root <- "data-raw/cache/hamilton"
d <- if (length(args) && args[1] != "claudelands") file.path(root, args[1]) else root
x <- readRDS(file.path(d, "run.rds"))
base <- x$sc
base$name <- "Base"
rb <- base$rulebook
ov <- function(r, id) if (!is.null(r$overlays[[id]])) set_rule(r, paste0("overlays.", id, ".enabled"), FALSE) else r

rezone <- base$zoning
rezone$zone[rezone$zone %in% "General Residential"] <- "Medium Density Residential"
hha <- base$layers$heritage_area
hha_half <- if (!is.null(hha)) hha[seq_len(nrow(hha)) %% 2 == 1, ] else NULL

sc <- list(
  base,
  scenario_change(base, "Same", notes = "identical inputs"),
  scenario_change(base, "No PC14", rulebook = ov(rb, "flood_high")),
  scenario_change(base, "No heritage areas", rulebook = ov(rb, "heritage_area")),
  scenario_change(base, "GRZ to MRZ", zoning = rezone),
  scenario_change(base, "Combined", rulebook = ov(rb, "flood_high"), zoning = rezone,
                  layers = list(heritage_area = hha_half))
)
set <- do.call(scenario_set, sc)
t0 <- Sys.time()
res <- run_scenarios(set)
cat("runs (incremental):", round(as.numeric(Sys.time() - t0, units = "mins"), 1), "min\n")
cmp <- compare_scenarios(res)
print(cmp)
chk <- check_comparison(cmp)
print(chk)
cat("comparison checks failing:", sum(chk$status != "ok"), "of", nrow(chk), "\n")

# Shapley attribution for the combined change also sums to the change.
cmp_sh <- compare_scenarios(res, pairs = list(c("Base", "Combined")), attribution = "shapley")
print(cmp_sh$pairs[[1]]$attribution)
chk_sh <- check_comparison(cmp_sh)
cat("Shapley checks failing:", sum(chk_sh$status != "ok"), "of", nrow(chk_sh), "\n")
print(cmp$pairs[["Base -> Combined"]]$attribution)

# Incremental equals full, site by site.
key <- function(cap) {
  s <- sf::st_drop_geometry(cap$sites)
  s[order(s$site_id), c("site_id", "floor_area", "residential_floor_area", "dwellings", "minor_dwellings")]
}
for (nm in names(res)[-1]) {
  full <- estimate_capacity(set[[nm]])
  a <- key(res[[nm]]); b <- key(full)
  same_ids <- identical(a$site_id, b$site_id)
  dmax <- if (same_ids) max(abs(as.matrix(a[-1]) - as.matrix(b[-1]))) else NA
  cat(sprintf("%-18s incremental vs full: same sites %s, largest site difference %s\n", nm, same_ids, format(dmax)))
}

# Each change lands where it should, and moves capacity the right way.
s0 <- sf::st_drop_geometry(res[["Base"]]$sites)
gain <- function(nm) {
  s1 <- sf::st_drop_geometry(res[[nm]]$sites)
  m <- match(s0$site_id, s1$site_id)
  data.frame(site_id = s0$site_id, zone = s0$zone_key, d_floor = s1$floor_area[m] - s0$floor_area,
             d_dw = s1$dwellings[m] - s0$dwellings)
}
touch <- function(layer, buf = 0) {
  if (is.null(layer) || !nrow(layer)) return(rep(FALSE, nrow(s0)))
  g <- sf::st_union(sf::st_make_valid(sf::st_geometry(layer)))
  if (buf > 0) g <- sf::st_buffer(g, buf)
  lengths(sf::st_intersects(res[["Base"]]$sites, g)) > 0
}
report <- function(nm, where, label) {
  g <- gain(nm)
  # A rezoning can merge a parcel's zone pieces: sites missing from the
  # scenario count as changed, with their change left out of the sums.
  ch <- is.na(g$d_floor) | abs(g$d_floor) > 1e-6 | g$d_dw != 0
  g$d_floor[is.na(g$d_floor)] <- 0; g$d_dw[is.na(g$d_dw)] <- 0L
  cat(sprintf("%-18s %d sites change: %d %s, %d elsewhere; floor area %+.0f m2 (%d sites lose), dwellings %+d\n",
              nm, sum(ch), sum(ch & where), label, sum(ch & !where), sum(g$d_floor), sum(g$d_floor < -1e-6), sum(g$d_dw)))
  if (any(ch & !where)) print(utils::head(g[ch & !where, ], 8), row.names = FALSE)
  rs <- cmp$pairs[[paste("Base ->", nm)]]$sites$reason
  print(table(reason = rs))
}
g <- gain("Same")
cat(sprintf("Same               %d sites change\n", sum(abs(g$d_floor) > 1e-6 | g$d_dw != 0)))
report("No PC14", touch(base$layers$flood_high), "touching the flood layer")
report("No heritage areas", touch(base$layers$heritage_area), "touching a heritage area")
report("GRZ to MRZ", s0$zone_key %in% "GRZ", "General Residential")
