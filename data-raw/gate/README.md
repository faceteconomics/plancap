# Stage 4 gate: plancap against capacityengine on one Auckland tile

Tile `t_011_011` of capacityengine's operative region run: 2,680 sites, nine
zones (Single House, MHS, MHU, THAB, Neighbourhood, Local and Town Centre,
Mixed Use, Light Industry), the Devonport Peninsula precinct, the Height
Variation Control, height and building sensitive areas, special character,
coastal water. Run 21 November 2026.

## How

1. `export_ce_tile.R` (run in the capacityengine folder) saves the tile's own
   sites (with each zone-split piece's parent), road parcels, zoning,
   overlay layers, precincts, water, ground levels and height surface
   rasters; the context capacityengine reads within 150 m (easement areas,
   the other primary parcels, building outlines, named road sections, and
   the region's sites as the front yard's neighbours); and capacityengine's
   results for the tile in four runs (below), plus the published rows.
2. `compare_tile.R [tile] [mode]` (run in plancap) runs `estimate_capacity()`
   on those inputs with the converted Auckland rulebook and compares site by
   site.
3. `debug_sites_ce.R` and `debug_sites_pc.R` print one site's storeys and
   setbacks in each engine (`TERRAIN=1` for terrain).

## Result: exact in every mode

| mode | capacityengine run | floor area | dwellings | sites exact (floor area, dwellings) |
|---|---|---|---|---|
| `nofront` | flat ground, no measured front yard | 1,670,543 m2 | 6,221 | 2,680, 2,680 |
| `flat` | flat ground, measured front yard | 1,654,391 m2 | 6,214 | 2,680, 2,680 |
| `terrain` | stepped terrain and height surfaces, no measured front yard | 1,661,340 m2 | 6,185 | 2,680, 2,680 |
| `full` | terrain, surfaces and the measured front yard (the published settings) | 1,645,691 m2 | 6,178 | 2,680, 2,680 |

plancap's totals equal capacityengine's in each mode, and every site matches
floor area to 0.01 m2 and dwellings exactly. A run takes 36 s flat and 50 s
with terrain and surfaces.

## What the gate found and fixed in plancap

Stage 4, part 3 (flat ground):

1. A zone's storey height where it states no storey count: occupiable height
   divided into as many default-height storeys as fit (20 m: six of 3.33 m).
2. Zone families conditional on the contiguous area of the land across the
   boundary (`zone_family(min_area, max_area)`): capacityengine's
   `OPEN_SPACE_UNDER_2000` and `OPEN_SPACE_OVER_2000_WIDE`.
3. A site with no measurable access is not capped by the access width table,
   and is flagged (capacityengine item 260).
4. Large sites count by the CfGS divisor where the region run does.
5. Precinct names carry their sub-precinct; a site under a precinct and its
   sub-precinct counts once.

Part 4 (terrain): stepped terrain, boundary runs and ground planes; ground
levels supplied as tables; height surfaces need ground levels because they
are absolute elevations (a maunga viewshaft at 18.5 m over ground at 28.2 m
leaves only its 9 m floor height).

Part 5:

6. The 17 irregular special character lots that differed were not a
   classification difference: capacityengine gives a rear site's side
   boundaries the rear yard (AUP J1, item 319: 1.2 m side against 3 m rear in
   Special Character). Now the morphology setting `rear_site_sides_as_rear`,
   on in the converted rulebooks; boundary runs and the shape factor still
   read those boundaries as sides, as capacityengine does.
7. The measured front yard needs capacityengine's neighbours: its region
   sites, not every primary parcel. With all parcels a reserve or school
   whose building stands 350 m back became a "dwelling on an adjacent site"
   (`scenario(neighbours = )`).
8. Access width: measured from easements and access lots (item 259), and
   shared by the pieces of one landholding (`scenario(landholding = )`).
9. The shape factor measured water yards from the boundary as well as from
   the water; now from the water only, as the envelope does.
10. Ground tables are matched by segment midpoint: a zone-split piece's
    boundary starts at a different vertex in the two engines.
11. Height surface banding for all partly covered sites in one pass: the
    terrain run fell from 158 s to 50 s.
