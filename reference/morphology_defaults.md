# Morphology defaults

The assumptions behind identifying what each boundary and site is (road
frontage, side or rear boundary, corner site, rear site, access leg).
Each can be overridden in a rulebook with
[`set_morphology()`](https://faceteconomics.github.io/plancap/reference/set_rules.md)
and again for a single run.

## Usage

``` r
morphology_defaults()
```

## Value

A named list:

- `min_road_contact`:

  Shortest total road frontage (m) for a site to count as fronting a
  road. 0.5.

- `road_tolerance`:

  Distance (m) within which a boundary counts as running along a road
  parcel, absorbing cadastral slivers. A boundary segment is a road
  frontage when at least half its length is within it. 0.5.

- `boundary_probe_distance`:

  How far (m) across a side or rear boundary to look for the zone
  opposite. 1.

- `road_probe_distance`:

  How far (m) across a road boundary to look for the zone opposite, so
  the probe clears the carriageway. 25.

- `side_rear_angle_tolerance`:

  Degrees from parallel to the frontage within which a boundary is a
  rear boundary. 30.

- `rear_depth_share`:

  How far back (as a share of the site's depth from the frontage) a
  parallel boundary must sit to be a rear boundary. 0.5.

- `rear_site_max_frontage`:

  A site with less road frontage than this (m) is a rear site. 7.5.

- `corner_angle_tolerance`:

  Degrees by which two frontages must differ in bearing for a corner
  site. 30.

- `corner_min_frontage`:

  Shortest frontage (m) on each road for a corner site. 3.

- `through_min_bearing_difference`:

  Degrees between two frontages for a through site. 135.

- `access_leg_max_width`:

  Widest (m) an access leg (driveway strip of a rear site) may be. 7.5.

- `access_leg_min_road_contact`:

  Shortest road contact (m) of an access leg. 0.5.

- `exclude_access_legs`:

  Whether access legs are left out of net site area. `TRUE`.

- `boundary_merge_angle`:

  Degrees within which consecutive boundary segments count as one
  straight boundary. 5.

- `water_boundary_distance`:

  Distance (m) from a water feature within which a boundary is classed
  coastal, riparian or lakeside. 20.

- `reserve_families`:

  Zone families whose land makes a boundary a reserve boundary.
  `"OPEN_SPACE"`.

- `min_sliver_area`:

  Pieces of a site (m2) smaller than this, left by a zone boundary, are
  merged into the larger piece. 1.

- `access_touch_distance`:

  Distance (m) within which an easement or access lot counts as reaching
  a rear site
  ([`find_access_widths()`](https://faceteconomics.github.io/plancap/reference/find_access_widths.md)).
  0.5.

- `access_contact_tolerance`:

  Distance (m) within which a boundary counts as on a road when
  measuring access width. Small, because cadastral boundaries share
  surveyed vertices. 0.05.

- `access_max_strip_width`:

  Road contact wider than this (m) is a lot, not an access strip. 10.

- `access_lot_max_area`:

  Largest parcel (m2) taken as a possible jointly owned access lot. 800.

- `front_setback_neighbours`:

  Neighbouring sites on each side whose dwellings set a measured front
  yard
  ([`find_existing_front_setbacks()`](https://faceteconomics.github.io/plancap/reference/find_existing_front_setbacks.md)).
  3.

- `front_setback_min_dwelling_area`:

  Smallest building (m2) counted as a dwelling there, so a garage or
  shed is not. 50.

- `front_setback_max_offset`:

  A parcel further than this (m) from the street line is not taken to
  front it. 60.

- `rear_site_sides_as_rear`:

  Whether a rear site's side boundaries are rear boundaries, where a
  plan defines a rear site's yards as all rear yards (Auckland Unitary
  Plan J1: a rear yard "Includes: all yards on a rear site"). They are
  tagged `rear_site_side`. `FALSE`.

## Examples

``` r
morphology_defaults()$corner_angle_tolerance
#> [1] 30
```
