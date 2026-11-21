# Build Exampleton Plan Change 1's map changes, on top of the shipped town.
#
# Run from the package root, after data-raw/exampleton.R:
#   Rscript data-raw/exampleton_pc1.R
# Writes inst/extdata/exampleton_pc1.gpkg with three layers:
#   * zoning: the operative zoning with the MDR blocks whose centre is within
#     600 m of the station rezoned to the new Terraced Housing zone (THZ);
#   * flood_hazard: the flood plain widened from 45 m to 70 m either side of
#     the stream (a new hazard study);
#   * parcels: the operative parcels with one low density block re-subdivided
#     into new lots (new parcel ids, "N" numbers).
# The rule changes are in inst/rulebooks/exampleton_pc1.yaml.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(sf)
})
town <- exampleton()
crs <- st_crs(town$parcels)

# ---- Rezoning near the station ----------------------------------------------
station <- st_geometry(town$transit)[1]
z <- town$zoning
mdr_blocks <- st_cast(st_geometry(z[z$zone == "MDR", ]), "POLYGON")
near <- as.numeric(st_distance(st_centroid(mdr_blocks), station)) < 600
thz <- st_union(mdr_blocks[near])
g <- st_geometry(z)
g[z$zone == "MDR"] <- st_difference(g[z$zone == "MDR"], thz)
st_geometry(z) <- g
add <- z[z$zone == "MDR", ]
add$zone <- "THZ"
add$label <- "Terraced Housing"
st_geometry(add) <- st_sfc(thz, crs = crs)
zoning <- rbind(z, add)
cat(sum(near), "MDR blocks rezoned THZ\n")

# ---- A wider flood plain -----------------------------------------------------
extent <- st_as_sfc(st_bbox(town$parcels))
flood_hazard <- st_sf(name = "Stream flood plain (PC1 hazard study)", hazard = "flood",
                      geometry = st_intersection(st_buffer(st_geometry(town$water), 70), extent))

# ---- One block re-subdivided ---------------------------------------------------
# A two-row low density block, its lots replaced by 12 m lots in two rows
# fronting the roads north and south.
p <- town$parcels
land <- p[p$parcel_type == "land", ]
ldr_blocks <- st_cast(st_geometry(zoning[zoning$zone == "LDR", ]), "POLYGON")
bb <- lapply(ldr_blocks, st_bbox)
deep <- which(vapply(bb, function(b) b[["ymax"]] - b[["ymin"]], 0) > 90)
blk <- ldr_blocks[deep[1]]
inside <- lengths(st_within(st_point_on_surface(st_geometry(land)), blk)) > 0
b <- st_bbox(blk)
w <- 12
nx <- floor((b[["xmax"]] - b[["xmin"]]) / w)
xs <- b[["xmin"]] + c(seq(0, nx - 1) * w, b[["xmax"]] - b[["xmin"]])
ym <- (b[["ymin"]] + b[["ymax"]]) / 2
rect <- function(x0, y0, x1, y1) st_polygon(list(matrix(c(x0, y0, x1, y0, x1, y1, x0, y1, x0, y0), ncol = 2, byrow = TRUE)))
lots <- c(lapply(seq_len(nx), function(i) rect(xs[i], b[["ymin"]], xs[i + 1], ym)),
          lapply(seq_len(nx), function(i) rect(xs[i], ym, xs[i + 1], b[["ymax"]])))
new <- p[0, ]
new <- p[rep(which(p$parcel_type == "land")[1], length(lots)), ]
for (cc in setdiff(names(new), c("parcel_id", "parcel_type", attr(new, "sf_column")))) new[[cc]] <- NA
new$parcel_id <- sprintf("N%03d", seq_along(lots))
new$parcel_type <- "land"
st_geometry(new) <- st_sfc(lots, crs = crs)
old_ids <- land$parcel_id[inside]
parcels <- rbind(p[!p$parcel_id %in% old_ids, ], new)
cat(length(old_ids), "lots replaced by", nrow(new), "new lots\n")
stopifnot(all(st_is_valid(parcels)), abs(as.numeric(sum(st_area(new)) - sum(st_area(land[inside, ])))) < 1)

gpkg <- "inst/extdata/exampleton_pc1.gpkg"
if (file.exists(gpkg)) invisible(file.remove(gpkg))
st_write(zoning, gpkg, layer = "zoning", quiet = TRUE)
st_write(flood_hazard, gpkg, layer = "flood_hazard", quiet = TRUE)
st_write(parcels, gpkg, layer = "parcels", quiet = TRUE)
cat("wrote", gpkg, "\n")
