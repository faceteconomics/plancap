#' Rulebooks shipped with plancap
#'
#' plancap ships the Exampleton rulebook (for the synthetic town from
#' [exampleton()]) and, as dated worked examples, rulebooks for three New
#' Zealand councils: Auckland (Auckland Unitary Plan, operative), Christchurch
#' and Wellington. The council rulebooks were converted from the capacityengine
#' project and carry every rule citation; check the plan itself before relying
#' on any value.
#'
#' @param name Name of a shipped rulebook; see `rulebook_examples()`.
#' @param validate Whether to validate on reading (the council rulebooks give
#'   warnings for values whose citation was not recorded).
#' @return `rulebook_example()` returns a `plancap_rulebook`;
#'   `rulebook_examples()` the available names; `rulebook_example_path()` the
#'   file path.
#' @export
#' @examples
#' rulebook_examples()
#' rb <- rulebook_example("exampleton")
#' rb
#' head(rule_table(rb))
rulebook_example <- function(name = "exampleton", validate = FALSE) {
  read_rulebook(rulebook_example_path(name), validate = validate)
}

#' @rdname rulebook_example
#' @export
rulebook_examples <- function() {
  f <- list.files(system.file("rulebooks", package = "plancap"), pattern = "\\.yaml$")
  sub("\\.yaml$", "", f)
}

#' @rdname rulebook_example
#' @export
rulebook_example_path <- function(name = "exampleton") {
  name <- rlang::arg_match(name, rulebook_examples())
  system.file("rulebooks", paste0(name, ".yaml"), package = "plancap", mustWork = TRUE)
}
