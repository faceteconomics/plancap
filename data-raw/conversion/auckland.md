# Conversion report: auckland

Source: `../capacityengine/inst/plans/auckland/aup-oip-2025.yaml`  
Converted: 2026-11-20 13:43

Validation: valid, 97 warnings.

## Fields not carried across

- `overlays/height_and_building_sensitive_area :: sub_areas` (list(list(source_layer = "hsa_13m_areas", value = 13L, source = "AUP D14.4.1 (A8), areas in Figure D14.10.1")))
- `overlays/maunga_viewshaft :: class_field` ("viewshaft_significance")
- `overlays/special_character/overrides/yards/front :: value_from (yard set from neighbours' existing setbacks; not representable)` ("existing_dwelling_setback_average")
- `zones/RES_MHS :: cfgs_large_site_area_per_dwelling_m2` (300L)
- `zones/RES_MHS :: cfgs_large_site_area_per_dwelling_m2 (CfGS fidelity mode only)` 
- `zones/RES_MHU :: cfgs_large_site_area_per_dwelling_m2` (300L)
- `zones/RES_MHU :: cfgs_large_site_area_per_dwelling_m2 (CfGS fidelity mode only)` 
- `zones/RES_THAB :: cfgs_large_site_area_per_dwelling_m2` (300L)
- `zones/RES_THAB :: cfgs_large_site_area_per_dwelling_m2 (CfGS fidelity mode only)` 

## Validation issues

- warning: `/zones/RES_LARGE_LOT/ratios/coverage_max` ratio has no source
- warning: `/zones/RES_LARGE_LOT/ratios/impervious_max` ratio has no source
- warning: `/zones/RES_SINGLE_HOUSE/ratios/coverage_max` ratio has no source
- warning: `/zones/RES_SINGLE_HOUSE/ratios/landscaping_min` ratio has no source
- warning: `/zones/RES_SINGLE_HOUSE/ratios/impervious_max` ratio has no source
- warning: `/zones/RES_MHS/ratios/coverage_max` ratio has no source
- warning: `/zones/RES_MHS/ratios/landscaping_min` ratio has no source
- warning: `/zones/RES_MHS/ratios/impervious_max` ratio has no source
- warning: `/zones/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/zones/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/zones/RES_MHU/ratios/impervious_max` ratio has no source
- warning: `/zones/RES_THAB/ratios/coverage_max` ratio has no source
- warning: `/zones/RES_THAB/ratios/landscaping_min` ratio has no source
- warning: `/zones/RES_THAB/ratios/impervious_max` ratio has no source
- warning: `/zones/BUS_TOWN_CENTRE/height` height has no source
- warning: `/zones/RES_RURAL_COASTAL/ratios/coverage_max` ratio has no source
- warning: `/zones/RES_RURAL_COASTAL/ratios/impervious_max` ratio has no source
- warning: `/overlays/special_character/parameters/ratios/coverage_max` ratio has no source
- warning: `/overlays/special_character/parameters/ratios/landscaping_min` ratio has no source
- warning: `/overlays/special_character/parameters/ratios/paved_max` ratio has no source
- warning: `/overlays/natural_hazards` overlay has no source
- warning: `/areas/kingseat/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/greenhithe/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/hingaia_3/zone_parameters/RES_MHS/ratios/coverage_max` ratio has no source
- warning: `/areas/hingaia_3/zone_parameters/RES_MHS/ratios/impervious_max` ratio has no source
- warning: `/areas/hingaia_3/zone_parameters/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/areas/hingaia_3/zone_parameters/RES_MHU/ratios/impervious_max` ratio has no source
- warning: `/areas/beachlands_south/zone_parameters/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/areas/beachlands_south/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/beachlands_south/zone_parameters/RES_THAB/ratios/coverage_max` ratio has no source
- warning: `/areas/beachlands_south/zone_parameters/RES_THAB/ratios/landscaping_min` ratio has no source
- warning: `/areas/beachlands_south/zone_parameters/RES_LARGE_LOT/ratios/coverage_max` ratio has no source
- warning: `/areas/beachlands_south/zone_parameters/RES_LARGE_LOT/ratios/impervious_max` ratio has no source
- warning: `/areas/drury_1/zone_parameters/RES_MHS/ratios/coverage_max` ratio has no source
- warning: `/areas/drury_1/zone_parameters/RES_MHS/ratios/landscaping_min` ratio has no source
- warning: `/areas/drury_1/zone_parameters/RES_MHS/ratios/impervious_max` ratio has no source
- warning: `/areas/drury_1/zone_parameters/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/areas/drury_1/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/drury_1/zone_parameters/RES_MHU/ratios/impervious_max` ratio has no source
- warning: `/areas/waimanawa/zone_parameters/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/areas/waimanawa/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/waimanawa/zone_parameters/RES_THAB/ratios/coverage_max` ratio has no source
- warning: `/areas/waimanawa/zone_parameters/RES_THAB/ratios/landscaping_min` ratio has no source
- warning: `/areas/scott_point/zone_parameters/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/areas/scott_point/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/scott_point/zone_parameters/RES_MHU/ratios/impervious_max` ratio has no source
- warning: `/areas/beachlands_1/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/beachlands_1/parameters/ratios/impervious_max` ratio has no source
- warning: `/areas/babich/sub_areas/A/zone_parameters/RES_LARGE_LOT/ratios/coverage_max` ratio has no source
- warning: `/areas/babich/sub_areas/A/zone_parameters/RES_LARGE_LOT/ratios/impervious_max` ratio has no source
- warning: `/areas/albany_9/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/hingaia_2/zone_parameters/RES_MHS/ratios/landscaping_min` ratio has no source
- warning: `/areas/hingaia_2/zone_parameters/RES_MHS/ratios/impervious_max` ratio has no source
- warning: `/areas/hingaia_2/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/dairy_flat/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/silverdale_2/parameters/ratios/landscaping_min` ratio has no source
- warning: `/areas/huapai_triangle/zone_parameters/RES_MHS/ratios/coverage_max` ratio has no source
- warning: `/areas/huapai_triangle/zone_parameters/RES_MHS/ratios/landscaping_min` ratio has no source
- warning: `/areas/orewa_3/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/orewa_3/parameters/ratios/landscaping_min` ratio has no source
- warning: `/areas/orewa_3/parameters/ratios/impervious_max` ratio has no source
- warning: `/areas/wairaka/zone_parameters/BUS_MIXED_USE/ratios/landscaping_min` ratio has no source
- warning: `/areas/devonport_peninsula/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/devonport_peninsula/parameters/ratios/landscaping_min` ratio has no source
- warning: `/areas/pukekohe_east_central_2/zone_parameters/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/areas/pukekohe_east_central_2/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/whenuapai_1/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/opaheke_1/zone_parameters/RES_MHS/ratios/coverage_max` ratio has no source
- warning: `/areas/opaheke_1/zone_parameters/RES_MHS/ratios/landscaping_min` ratio has no source
- warning: `/areas/opaheke_1/zone_parameters/RES_MHU/ratios/coverage_max` ratio has no source
- warning: `/areas/opaheke_1/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/akoranga_1/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/albany_10/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/ardmore_2/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/ardmore_2/parameters/ratios/landscaping_min` ratio has no source
- warning: `/areas/ardmore_2/parameters/ratios/impervious_max` ratio has no source
- warning: `/areas/whenuapai_2/zone_parameters/RES_MHU/ratios/landscaping_min` ratio has no source
- warning: `/areas/huapai_2/zone_parameters/RES_MHS/ratios/coverage_max` ratio has no source
- warning: `/areas/huapai_2/zone_parameters/RES_MHS/ratios/landscaping_min` ratio has no source
- warning: `/areas/huapai_2/zone_parameters/RES_MHS/ratios/impervious_max` ratio has no source
- warning: `/areas/three_kings/zone_parameters/RES_THAB/ratios/coverage_max` ratio has no source
- warning: `/areas/three_kings/zone_parameters/RES_THAB/ratios/landscaping_min` ratio has no source
- warning: `/areas/three_kings/zone_parameters/RES_THAB/ratios/impervious_max` ratio has no source
- warning: `/areas/epsom/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/manukau_2/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/boat_building/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/remuera/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/remuera/parameters/ratios/landscaping_min` ratio has no source
- warning: `/areas/highbrook/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/highbrook/parameters/ratios/landscaping_min` ratio has no source
- warning: `/areas/mount_albert_2/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/crestview_rise/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/crestview_rise/parameters/ratios/landscaping_min` ratio has no source
- warning: `/areas/viaduct_harbour/parameters/ratios/far_max` ratio has no source
- warning: `/areas/takapuna_2/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/eaglehurst_road/parameters/ratios/coverage_max` ratio has no source
- warning: `/areas/eaglehurst_road/parameters/ratios/landscaping_min` ratio has no source
