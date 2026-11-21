# Read a set of scenarios from a manifest file

A manifest describes every scenario of a comparison in one YAML file, so
the comparison is reproducible from files alone. Each scenario has a
`name`, and either all of its inputs or `changes:` naming an earlier
scenario and only the inputs that differ (layers are merged by name, as
in
[`scenario_change()`](https://faceteconomics.github.io/plancap/reference/scenario.md)).
The first scenario is the baseline.

## Usage

``` r
read_scenarios(path)
```

## Arguments

- path:

  The manifest file.

## Value

A
[`scenario_set()`](https://faceteconomics.github.io/plancap/reference/scenario_set.md).

## Details

    scenarios:
      - name: Operative
        rulebook: example:exampleton            # or a path to a rulebook file
        parcels: {path: exampleton.gpkg, layer: parcels, filter: {parcel_type: land}}
        roads: {path: exampleton.gpkg, layer: parcels, filter: {parcel_type: road}}
        zoning: {path: exampleton.gpkg, layer: zoning}
        layers:
          height_areas: {path: exampleton.gpkg, layer: height_areas}
      - name: PC1
        changes: Operative
        rulebook: example:exampleton_pc1
        zoning: {path: exampleton_pc1.gpkg, layer: zoning}

A layer is a path to a file `sf` can read, or a list with `path`, an
optional `layer` and an optional `filter` (column to allowed values).
Paths are relative to the manifest. Other scenario arguments (such as
`zone_field`, `site_id`, `group_by`, `street_field`, `landholding`) are
given by name.

## Examples

``` r
set <- read_scenarios(system.file("extdata", "exampleton_pc1_scenarios.yaml", package = "plancap"))
set
#> <plancap scenario set> 2 scenarios; baseline "Operative".
#> PC1 as notified: rulebook, parcels, zoning, layers differ
```
