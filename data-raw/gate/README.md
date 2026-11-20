# Stage 4 gate: plancap against capacityengine on one Auckland tile

Tile `t_011_011` of capacityengine's operative region run: 2,680 sites, nine
zones (Single House, MHS, MHU, THAB, Neighbourhood, Local and Town Centre,
Mixed Use, Light Industry), the Devonport Peninsula precinct, the Height
Variation Control, height and building sensitive areas, special character.
Run 20 November 2026.

## How

1. `export_ce_tile.R` (run in the capacityengine folder) saves the tile's own
   sites, road parcels, zoning, overlay layers, precincts and water, and
   capacityengine's results for the tile: on flat ground (the cached datum
   switched off), on flat ground without the special character front yard
   measured from the neighbours' houses (`nofront`), and as published.
2. `compare_tile.R` (run in plancap) runs `estimate_capacity()` on those
   inputs with the converted Auckland rulebook and compares site by site.
3. `debug_sites_ce.R` and `debug_sites_pc.R` print one site's storeys and
   setbacks in each engine.

## Result (flat ground, like for like)

| | capacityengine | plancap | difference |
|---|---|---|---|
| Floor area | 1,670,543 m2 | 1,671,099 m2 | +0.033% |
| Dwellings | 6,221 | 6,189 | -0.51% |
| Sites matching floor area to 0.01 m2 | | | 2,663 of 2,680 (99.4%) |
| Sites matching dwellings exactly | | | 2,623 (97.9%) |

Every zone but Single House matches floor area to rounding. What is left,
each traced to its cause:

- **Floor area, +557 m2 on 17 small special-character Single House lots.**
  Boundary classification (side or rear) differs on irregular lots between
  capacityengine's precomputed segments and plancap's.
- **Dwellings, -32, all at the access width cap.** capacityengine measures
  access width from easements and rights of way (its item 259); plancap reads
  road frontage. Where neither can measure access the site is left uncapped
  and flagged in both.
- **Not like for like: the special character front yard set from the
  neighbours' existing houses** (`value_from`, capacityengine item 314/362).
  Not carried by the conversion; with it, capacityengine's flat figure is
  1,654,391 m2 (plancap +1.0%).
- **Not compared yet: terrain.** capacityengine's published figure (stepped
  terrain on a sloping-site ground plane, item 318) is 1,645,691 m2, 0.5%
  below its flat run; plancap's stepped terrain is the next piece of work.

## What the gate found and fixed in plancap

1. A zone's storey height where it states no storey count: occupiable height
   divided into as many default-height storeys as fit (20 m: six of 3.33 m),
   capacityengine's rule; plancap had used the default.
2. Zone families conditional on the contiguous area of the land across the
   boundary (`zone_family(min_area, max_area)`): capacityengine's
   `OPEN_SPACE_UNDER_2000` and `OPEN_SPACE_OVER_2000_WIDE`. Without it the
   "next to small open space" plane applied beside every reserve (59 MHU
   sites).
3. A site with no road frontage has no measurable access: the access cap does
   not apply and the site is flagged (capacityengine item 260), not capped at
   zero.
4. Large sites count by capacityengine's CfGS divisor where its region run
   does (`large_site_dwellings: divisor`); the converter had dropped it.
5. Precinct names carry their sub-precinct ("Devonport Peninsula
   sub-precinct E"): the data adapter splits them, as capacityengine does,
   and a site under a precinct and its sub-precinct counts once.
