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

  Shortest length (m) of shared edge with a road parcel that makes a
  boundary a road frontage. 0.5.

- `road_probe_distance`:

  How far (m) across a road boundary to look for the zone opposite, so
  the probe clears the carriageway. 25.

- `side_rear_angle_tolerance`:

  Degrees from parallel to the frontage within which a boundary is a
  rear boundary. 30.

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

## Examples

``` r
morphology_defaults()$corner_angle_tolerance
#> [1] 30
```
