# Setback rules: yards, planes and everything that keeps a building back

Every rule that keeps a building a distance from a boundary, from a
simple yard to a recession plane, a sky exposure plane or a setback
proportional to height, is held as a **setback**: a required distance
from an origin line as a function of height, \\d(h)\\. The engine takes,
for each boundary at each storey, the largest distance any applicable
rule requires.

## Usage

``` r
yard(
  distance,
  boundaries,
  from_storey = NULL,
  above_height = NULL,
  origin = "boundary",
  when = NULL,
  variant = NULL,
  name = NULL,
  source = NULL,
  activity_status = NULL
)

plane(
  angle_deg = NULL,
  start_height,
  boundaries,
  slope = NULL,
  set_in = 0,
  angle_by_bearing = NULL,
  angle_by_orientation = NULL,
  vertical_above = NULL,
  max_setback_above = NULL,
  datum = "boundary",
  origin = "boundary",
  when = NULL,
  variant = NULL,
  name = NULL,
  source = NULL,
  activity_status = NULL
)

upper_level_setback(
  distance,
  boundaries,
  above_height = NULL,
  from_storey = NULL,
  origin = "boundary",
  when = NULL,
  variant = NULL,
  name = NULL,
  source = NULL,
  activity_status = NULL
)

proportional_setback(
  ratio,
  boundaries,
  min = 0,
  max = NULL,
  origin = "boundary",
  when = NULL,
  variant = NULL,
  name = NULL,
  source = NULL,
  activity_status = NULL
)

setback_profile(
  height,
  distance,
  boundaries,
  origin = "boundary",
  when = NULL,
  variant = NULL,
  name = NULL,
  source = NULL,
  activity_status = NULL
)
```

## Arguments

- distance:

  Required distance (m), or a formula string. For `setback_profile()`,
  the distances (m) required at each of `height`.

- boundaries:

  Boundary classes the rule applies to, e.g. `"road"`, `"side"`,
  `"rear"`. See
  [`boundary_classes()`](https://faceteconomics.github.io/plancap/reference/boundary_classes.md).

- from_storey:

  Applies only from this storey up (1 = ground).

- above_height:

  Applies only to the part of a building above this height (m).

- origin:

  Line the distance is measured from: `"boundary"` (default),
  `"road_far_side"` (the far side of the road in front, as Japan's road
  slant line) or `"road_centreline"`.

- when:

  Conditions under which the rule applies, from
  [`conditions()`](https://faceteconomics.github.io/plancap/reference/conditions.md).

- variant:

  Name of the alternative standard this rule belongs to. Rules of
  different variants are alternatives, never combined.

- name:

  Optional label for the rule.

- source:

  Citation (plan, chapter, rule number).

- activity_status:

  Optional activity status of the standard.

- angle_deg:

  Plane angle from horizontal, degrees.

- start_height:

  Height (m) above the origin line where the plane starts.

- slope:

  Alternative to `angle_deg`: rise per unit of horizontal run (e.g.
  `2.7` for a 2.7:1 plane).

- set_in:

  Horizontal distance (m) inside the origin line where the plane starts.

- angle_by_bearing:

  Optional: angles that vary with the direction the boundary faces, as a
  data frame with `from_deg`, `to_deg` and `angle_deg` (bearing of the
  outward normal, clockwise from north).

- angle_by_orientation:

  Optional: angles at the four cardinal bearings,
  `c(north = , east = , south = , west = )`, graded linearly in between
  (Christchurch's recession plane diagrams work this way).

- vertical_above:

  Height (m) above which the plane turns vertical: the setback stays at
  its value at this height.

- max_setback_above:

  Optional cap on the plane's setback above a height, by the direction
  the boundary faces:
  `c(height = , north = , east = , south = , west = )`. Above `height`
  the lesser of the plane and this setback applies.

- datum:

  Ground the start height is measured from: `"boundary"` (ground at the
  boundary, the default), `"site"` (site mean ground) or `"road"`.

- ratio:

  Distance per metre of height.

- min, max:

  Bounds on the distance (m).

- height:

  For `setback_profile()`: breakpoints of height (m, ascending).
  Distances between breakpoints are interpolated; beyond the last they
  stay at the last.

## Value

A list with class `plancap_setback`.

## Details

- `yard()`: a fixed distance (or a formula), optionally only from a
  storey or above a height.

- `plane()`: a recession / daylight / height-in-relation-to-boundary
  plane, rising at an angle from a start height above the origin line.

- `upper_level_setback()`: an extra setback for the part of a building
  above a height (a podium step-back).

- `proportional_setback()`: a distance proportional to height, with a
  minimum and maximum (e.g. Germany's 0.4H, at least 3 m).

- `setback_profile()`: any piecewise-linear \\d(h)\\, for rules none of
  the above express.

Use
[`setback_distance()`](https://faceteconomics.github.io/plancap/reference/setback_distance.md)
to evaluate one.

## Examples

``` r
yard(3, "road", source = "Rule 7.1")
#> <setback: yard> on "road"
#>  $ distance:3
#>  $ source  :"Rule 7.1"
plane(angle_deg = 45, start_height = 2.5, boundaries = c("side", "rear"))
#> <setback: plane> on "side" and "rear"
#>  $ angle_deg   :45
#>  $ start_height:2.5
# NYC-style sky exposure plane on wide streets: 5.6 vertical to 1 horizontal
plane(slope = 5.6, start_height = 85 * 0.3048, boundaries = "road")
#> <setback: plane> on "road"
#>  $ angle_deg   :79.9
#>  $ start_height:25.9
proportional_setback(0.4, min = 3, boundaries = c("side", "rear"))
#> <setback: proportional> on "side" and "rear"
#>  $ ratio:0.4
#>  $ min  :3
setback_profile(height = c(0, 3.6, 6.9, 30), distance = c(1, 1, 2, 25.1),
                boundaries = c("side", "rear"))
#> <setback: profile> on "side" and "rear"
#>  $ points:List of 4
#>   ..$ :0 1
#>   ..$ :3.6 1
#>   ..$ :6.9 2
#>   ..$ :30 25.1
```
