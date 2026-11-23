# The plancap plot theme and colour scales

Every plancap plot uses one quiet theme, so the data is the only loud
thing on the page: a plain surface, hairline gridlines along the value
axis only, and text in three inks (primary, secondary, muted), never in
a series colour. `mode = "dark"` gives the same theme on a dark surface,
with colours stepped for it rather than inverted.

## Usage

``` r
theme_capacity(
  mode = c("light", "dark"),
  base_size = 11,
  base_family = "",
  grid = "y"
)

scale_fill_capacity_d(..., mode = "light")

scale_colour_capacity_d(..., mode = "light")

scale_fill_capacity_c(..., mode = "light")

scale_fill_capacity_div(..., midpoint = 0, mode = "light")
```

## Arguments

- mode:

  `"light"` or `"dark"`.

- base_size:

  Base font size (pt).

- base_family:

  Font family; default the system sans.

- grid:

  Which gridlines: `"x"`, `"y"`, `"both"` or `"none"`.

- ...:

  Passed to the ggplot2 scale.

- midpoint:

  Value at the grey midpoint of the diverging scale.

## Value

`theme_capacity()`: a ggplot2 theme. The scale functions return ggplot2
scales.

## Details

Colour has one job per scale:

- **categorical** (identity): eight hues in a fixed order, validated for
  colour vision deficiency between neighbours in both modes. Slots are
  never cycled: a ninth category is folded into "Other" (see
  [`capacity_palette()`](https://faceteconomics.github.io/plancap/reference/capacity_palette.md));

- **sequential** (magnitude): one hue, blue, light to dark (on the dark
  surface, dark to light, so small values recede);

- **diverging** (gain or loss): blue for a gain and red for a loss,
  either side of a grey midpoint.

## See also

[`capacity_palette()`](https://faceteconomics.github.io/plancap/reference/capacity_palette.md)

## Examples

``` r
library(ggplot2)
ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_capacity()
```
