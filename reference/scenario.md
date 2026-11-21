# Scenarios: a rulebook with its maps and parcels

A **scenario** is everything that determines capacity: a rulebook, the
parcels, roads and water, the zoning layer, and the layers the
rulebook's overlays and areas refer to. Comparing plan changes means
comparing scenarios, and two scenarios may differ in any of these.

## Usage

``` r
scenario(
  name,
  rulebook,
  parcels,
  zoning,
  roads = NULL,
  layers = list(),
  water = NULL,
  centrelines = NULL,
  dem = NULL,
  ground = NULL,
  easements = NULL,
  other_parcels = NULL,
  buildings = NULL,
  streets = NULL,
  street_field = "name",
  neighbours = NULL,
  landholding = NULL,
  zone_field = "zone",
  site_id = NULL,
  group_by = NULL,
  width_field = "width_m",
  morphology = list(),
  notes = NULL
)

scenario_change(base, name, ...)
```

## Arguments

- name:

  Name of the scenario.

- rulebook:

  A `plancap_rulebook`.

- parcels:

  Parcels (or sites) as `sf` polygons in a projected CRS. Road, rail and
  water parcels should be left out (supply roads separately).

- zoning:

  Zoning polygons with a column of zone codes (`zone_field`) that the
  rulebook's `zone_map` maps to zone keys.

- roads:

  Road parcels (polygons).

- layers:

  Named list of the other layers the rulebook refers to (overlays,
  areas, and layers named in distance conditions), named as the rulebook
  names them.

- water:

  Water features, for riparian, coastal and lakeside boundaries.

- centrelines:

  Road centrelines with a width column (`width_field`).

- dem:

  Optional ground surface as a
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

- ground:

  Optional ground levels supplied directly instead of a `dem` (from a
  survey, or another model): a list with `sites` (a data frame of
  `site_id` and `ground_mean`) and `segments` (a data frame of
  `site_id`, `seq`, the segment's position in its site's boundary
  counting from 1, and `ground`, the mean ground level along it). Give
  the segment's midpoint as `x` and `y` instead of `seq` to match
  segments by position.

- easements:

  Optional easement areas (rights of way), for the access width of rear
  sites
  ([`find_access_widths()`](https://faceteconomics.github.io/plancap/reference/find_access_widths.md)).

- other_parcels:

  Optional parcels that are not sites (and not roads), among which
  jointly owned access lots are found.

- buildings:

  Optional building outlines, for yards set from the neighbours'
  existing setbacks
  ([`find_existing_front_setbacks()`](https://faceteconomics.github.io/plancap/reference/find_existing_front_setbacks.md)).

- streets:

  Optional named street centre lines for the same; default
  `centrelines`.

- street_field:

  Column of `streets` holding the street name.

- neighbours:

  Optional parcels beyond `parcels` that may be neighbours for a
  measured front yard (default `other_parcels`). Leave out parcels whose
  buildings are not dwellings, such as reserves and schools.

- landholding:

  Optional column of `parcels` naming the landholding each parcel
  belongs to, where parcels held together are still separate sites:
  pieces of one landholding share their best access width.

- zone_field:

  Column of `zoning` holding zone codes.

- site_id:

  Column of `parcels` to use as the site id. Default `"parcel_id"` if
  present, otherwise row numbers.

- group_by:

  Optional column of `parcels`: parcels sharing a value are one site
  (e.g. parcels held on one title).

- width_field:

  Column of `centrelines` holding road width (m).

- morphology:

  Named list of morphology settings for this scenario, overriding the
  rulebook's (see
  [`morphology_defaults()`](https://faceteconomics.github.io/plancap/reference/morphology_defaults.md)).

- notes:

  Free text.

- base:

  The scenario to start from.

- ...:

  For `scenario_change()`: any argument of `scenario()` to change.
  `layers` given here are merged into the base's layers by name (a layer
  set to `NULL` is removed).

## Value

A `plancap_scenario`.

## Details

`scenario_change()` starts from an existing scenario and changes only
what it is given, which is how a plan change is usually described.

## See also

[`prepare_sites()`](https://faceteconomics.github.io/plancap/reference/prepare_sites.md)

## Examples

``` r
town <- exampleton()
base <- scenario("Operative", rulebook_example("exampleton"),
                 parcels = town$parcels[town$parcels$parcel_type == "land", ],
                 roads = town$parcels[town$parcels$parcel_type == "road", ],
                 zoning = town$zoning,
                 layers = town[c("height_areas", "flood_hazard", "heritage",
                                 "trees", "precincts", "transit")],
                 water = town$water, centrelines = town$road_centrelines)
base
#> <plancap scenario> Operative
#> Rulebook: Exampleton District Plan; 1377 parcels; 7 zoning features; layers:
#> height_areas, flood_hazard, heritage, trees, precincts, transit.
taller <- scenario_change(base, "MDR at 16 m",
  rulebook = set_rule(base$rulebook, "zones.MDR.height.value", 16))
```
