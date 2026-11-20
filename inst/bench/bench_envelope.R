# Benchmark site preparation and the envelope engine.
#
# Run from the package root:  Rscript inst/bench/bench_envelope.R [copies]
#
# Tiles Exampleton `copies` x `copies` times (side by side, shifted so the
# towns do not overlap) and times prepare_sites() and build_envelopes(), so a
# change that makes the engine grow faster than the number of sites shows up.
# Two quadratic regressions were caught this way in capacityengine.

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
copies <- if (length(args)) as.integer(args[1]) else 3L

town <- exampleton()
shift <- function(x, dx, dy) {
  sf::st_geometry(x) <- sf::st_geometry(x) + c(dx, dy)
  sf::st_crs(x) <- 2193
  x
}
tile <- function(layer, id_cols = character()) {
  out <- list()
  for (i in seq_len(copies)) for (j in seq_len(copies)) {
    y <- shift(layer, (i - 1) * 2000, (j - 1) * 1200)
    for (c in id_cols) y[[c]] <- paste0(y[[c]], "-", i, "-", j)
    out[[length(out) + 1]] <- y
  }
  do.call(rbind, out)
}
p <- tile(town$parcels, c("parcel_id", "title_id"))
sc <- scenario("Bench", rulebook_example("exampleton"),
               parcels = p[p$parcel_type == "land", ], roads = p[p$parcel_type == "road", ],
               zoning = tile(town$zoning), layers = list(height_areas = tile(town$height_areas),
                                                         precincts = tile(town$precincts)),
               water = tile(town$water))
clear_site_cache()
t <- system.time(s <- prepare_sites(sc))[["elapsed"]]
cat(sprintf("%d sites: prepare_sites %.1f s (%.2f ms a site)\n", nrow(s$sites), t, 1000 * t / nrow(s$sites)))
t <- system.time(e <- build_envelopes(sc))[["elapsed"]]
cat(sprintf("%d sites: build_envelopes %.1f s (%.2f ms a site), %s m2\n", nrow(e$sites), t,
            1000 * t / nrow(e$sites), format(round(sum(e$sites$floor_area)), big.mark = ",")))
ch <- scenario_change(sc, "MDR taller", rulebook = set_rule(sc$rulebook, "zones.MDR.height",
                                                             list(value = 15, occupiable = 14, roof_allowance = 1,
                                                                  storeys = 4, source = "bench")))
t <- system.time(e2 <- build_envelopes(ch, baseline = e))[["elapsed"]]
cat(sprintf("incremental (MDR changed): %.1f s, %d of %d sites copied\n", t,
            e2$report$copied_from_baseline, nrow(e2$sites)))
