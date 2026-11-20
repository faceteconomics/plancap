# Exampleton: a synthetic town for examples and tests

Exampleton is a made-up town of about 1,500 parcels, built by the script
in `data-raw/exampleton.R` so that every rule type plancap handles has
something to act on. It is placed in the sea about 250 km east of New
Zealand's North Island, in New Zealand Transverse Mercator (EPSG:2193),
so it cannot be mistaken for a real place.

## Usage

``` r
exampleton()

exampleton_layer(layer)

exampleton_layers()
```

## Arguments

- layer:

  Name of one layer. See `exampleton_layers()`.

## Value

`exampleton()` returns a named list of `sf` data frames, one per layer.
`exampleton_layer()` returns one `sf` data frame.

## Details

What it contains, and what each part is there to exercise:

|  |  |  |
|----|----|----|
| Layer | Geometry | Exercises |
| `parcels` | polygon | Land lots, road parcels and reserves in one layer, as a national cadastre supplies them (`parcel_type`). Corner lots, rear (battle-axe) lots with access legs, through lots, a large amalgamated site, and lots that share a `title_id` |
| `road_centrelines` | line | Street names and road reserve widths (`width_m`); Main Street is wider |
| `zoning` | polygon | Seven zones (`zone`); one block is split between two zones, so some lots straddle a zone boundary |
| `height_areas` | polygon | Mapped height limits (`max_height_m`) over the centre and its frame |
| `flood_hazard` | polygon | An exclusion along the river |
| `heritage` | polygon | A flag-only overlay on a few centre lots |
| `precincts` | polygon | One precinct with two sub-precincts (`sub_precinct`) |
| `water` | line | A river through the southern reserve, for riparian setbacks |
| `transit` | point | A station, for distance-band rules |
| `trees` | point | Trees with trunk diameter (`dbh_m`), `status` (`"protected"` or `"unprotected"`) and a root-zone `protection_radius_m` |
| `buildings` | polygon | Existing buildings with `storeys`, for net-of-existing capacity |

A ground surface is supplied separately as a 5 m raster; see
[`exampleton_dem()`](https://faceteconomics.github.io/plancap/reference/exampleton_dem.md).

## See also

[`exampleton_dem()`](https://faceteconomics.github.io/plancap/reference/exampleton_dem.md),
[`exampleton_path()`](https://faceteconomics.github.io/plancap/reference/exampleton_path.md)

## Examples

``` r
town <- exampleton()
names(town)
#>  [1] "parcels"          "road_centrelines" "zoning"           "height_areas"    
#>  [5] "flood_hazard"     "heritage"         "precincts"        "water"           
#>  [9] "transit"          "trees"            "buildings"       
table(town$parcels$parcel_type)
#> 
#>    land reserve    road 
#>    1377       2      88 

zones <- exampleton_layer("zoning")
zones$zone
#> [1] "TC"  "MU"  "HDR" "MDR" "LDR" "IND" "OS" 
```
