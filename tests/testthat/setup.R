# `$` partial-matches on lists (params$height once returned height_from_overlay
# in capacityengine). Make any partial match fail loudly in tests.
op <- options(warnPartialMatchDollar = TRUE, warnPartialMatchArgs = TRUE,
              warnPartialMatchAttr = TRUE)
withr::defer(options(op), teardown_env())
