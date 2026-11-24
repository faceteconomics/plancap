# Run the Hamilton rulebook on the fetched extracts (data-raw/hamilton/fetch.R).
#   Rscript data-raw/hamilton/run.R                 # every extract in the cache
#   Rscript data-raw/hamilton/run.R peacocke        # one
setwd("D:/Projects_cl/plancap")
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("data-raw/hamilton/prepare.R")
root <- "data-raw/cache/hamilton"
args <- commandArgs(trailingOnly = TRUE)
ex <- c("peacocke", "ruakura", "frankton", "thebase", "terapa", "university")
dirs <- c(claudelands = root, setNames(file.path(root, ex), ex))
dirs <- dirs[file.exists(file.path(dirs, "zoning.gpkg"))]
if (length(args)) dirs <- dirs[args]
rb <- read_rulebook("inst/extdata/hamilton_rulebook.xlsx")
for (nm in names(dirs)) {
  cat("\n==== ", nm, "\n")
  h <- hamilton_inputs(dirs[[nm]])
  print(table(h$zoning$zone, useNA = "ifany"))
  cat(nrow(h$parcels), "land parcels\n")
  sc <- scenario(paste("Hamilton,", nm), rb, parcels = h$parcels, roads = h$roads, zoning = h$zoning,
                 layers = h$layers, centrelines = h$centrelines)
  t0 <- Sys.time()
  cap <- estimate_capacity(sc)
  cat("secs", round(as.numeric(Sys.time() - t0, units = "secs"), 1), "\n")
  print(summary(cap))
  print(check_capacity(cap))
  print(constraint_breakdown(cap, by = "zone"))
  saveRDS(list(sc = sc, cap = cap), file.path(dirs[[nm]], "run.rds"))
}
