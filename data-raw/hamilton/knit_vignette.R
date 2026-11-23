# Knit the pre-computed "Adding a new jurisdiction" vignette.
# Run from the package root:  Rscript data-raw/hamilton/knit_vignette.R
# Needs data-raw/cache/hamilton/ (from data-raw/hamilton/fetch.R).
local({
  old <- setwd("vignettes")
  on.exit(setwd(old))
  knitr::knit("hamilton.Rmd.orig", "hamilton.Rmd", quiet = TRUE)
})
cat("knitted\n")
