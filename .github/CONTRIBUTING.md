# Contributing to plancap

Thank you for helping. Three kinds of contribution are especially welcome.

## 1. A rulebook for a new jurisdiction

plancap is built so that adding a jurisdiction needs no package code: only a
rulebook and the jurisdiction's zoning layer. If you have entered one,
please share it.

- Every value needs a `source`: the plan, chapter and rule it comes from.
  A number without a source cannot be checked.
- Use the highest limit that is still permitted (or its local equivalent of
  "as of right"). Where the plan allows open-ended breaches at a discretionary
  status, use the stated standard.
- Record every rule you could not model in `unmodelled_rules`, with the likely
  effect of modelling it (`overstates`, `understates` or `either`).
- Run `validate_rulebook()` before opening a pull request.

## 2. A rule the package cannot yet express

Open an issue with the **Rule not supported** template. Quote the rule text,
link the plan, and say how it is measured. A diagram helps a great deal.

## 3. Bugs and code

- Open an issue with a minimal reproducible example, ideally on
  `exampleton()`.
- For pull requests: one change per pull request, a test that fails before
  and passes after, a `NEWS.md` bullet, and `devtools::check()` clean.
- Code style follows the [tidyverse style guide](https://style.tidyverse.org).
  Geometry code must not loop over sites with GEOS calls inside; use spatial
  indexes and grouped operations.

## Code of conduct

Please note that this project is released with a
[Contributor Code of Conduct](https://faceteconomics.github.io/plancap/CODE_OF_CONDUCT.html).
By contributing you agree to abide by its terms.
