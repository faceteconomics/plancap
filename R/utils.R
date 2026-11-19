# Small internal helpers. Nothing here is exported.

`%||%` <- function(x, y) if (is.null(x)) y else x

# Drop NULL elements, keeping names.
compact <- function(x) x[!vapply(x, is.null, logical(1))]

is_number <- function(x) is.numeric(x) && length(x) == 1 && !is.na(x)
is_string <- function(x) is.character(x) && length(x) == 1 && !is.na(x)

check_number <- function(x, arg = rlang::caller_arg(x), lower = -Inf, upper = Inf,
                         null_ok = TRUE, call = rlang::caller_env()) {
  if (is.null(x) && null_ok) return(invisible(NULL))
  if (!is_number(x)) {
    cli::cli_abort("{.arg {arg}} must be a single number, not {.obj_type_friendly {x}}.",
                   call = call)
  }
  if (x < lower || x > upper) {
    cli::cli_abort("{.arg {arg}} must be between {lower} and {upper}, not {x}.", call = call)
  }
  invisible(x)
}

check_string <- function(x, arg = rlang::caller_arg(x), null_ok = TRUE,
                         call = rlang::caller_env()) {
  if (is.null(x) && null_ok) return(invisible(NULL))
  if (!is_string(x)) {
    cli::cli_abort("{.arg {arg}} must be a single string, not {.obj_type_friendly {x}}.",
                   call = call)
  }
  invisible(x)
}

check_character <- function(x, arg = rlang::caller_arg(x), null_ok = TRUE,
                            call = rlang::caller_env()) {
  if (is.null(x) && null_ok) return(invisible(NULL))
  if (!is.character(x) || anyNA(x) || !length(x)) {
    cli::cli_abort("{.arg {arg}} must be a character vector with no missing values.",
                   call = call)
  }
  invisible(x)
}

check_choice <- function(x, choices, arg = rlang::caller_arg(x), null_ok = TRUE,
                         call = rlang::caller_env()) {
  if (is.null(x) && null_ok) return(invisible(NULL))
  if (!is_string(x) || !x %in% choices) {
    cli::cli_abort("{.arg {arg}} must be one of {.or {.val {choices}}}, not {.val {x}}.",
                   call = call)
  }
  invisible(x)
}

check_flag <- function(x, arg = rlang::caller_arg(x), null_ok = TRUE,
                       call = rlang::caller_env()) {
  if (is.null(x) && null_ok) return(invisible(NULL))
  if (!is.logical(x) || length(x) != 1 || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be {.code TRUE} or {.code FALSE}.", call = call)
  }
  invisible(x)
}

# A value that may be a number or a formula string.
check_value <- function(x, arg = rlang::caller_arg(x), null_ok = TRUE,
                        call = rlang::caller_env()) {
  if (is.null(x) && null_ok) return(invisible(NULL))
  if (is_number(x)) return(invisible(x))
  if (is_string(x)) {
    parse_rule_formula(x, arg = arg, call = call)
    return(invisible(x))
  }
  cli::cli_abort("{.arg {arg}} must be a number or a formula string, not {.obj_type_friendly {x}}.",
                 call = call)
}

# Deep merge: `y` overrides `x`; named lists merge recursively, anything else
# (including unnamed lists such as setback lists) is replaced whole.
merge_lists <- function(x, y) {
  if (!is.list(x) || !is.list(y) || is.null(names(y)) || is.null(names(x))) return(y)
  for (nm in names(y)) {
    if (is.list(x[[nm]]) && is.list(y[[nm]]) && !is.null(names(y[[nm]])) &&
        !is.null(names(x[[nm]]))) {
      x[[nm]] <- merge_lists(x[[nm]], y[[nm]])
    } else {
      x[nm] <- list(y[[nm]])
    }
  }
  x
}

# Escape braces so text can pass through cli's glue interpolation verbatim.
esc <- function(x) gsub("}", "}}", gsub("{", "{{", x, fixed = TRUE), fixed = TRUE)
