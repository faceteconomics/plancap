#' Measure the legal access to rear sites
#'
#' Access width tables (a density rule's `access_width`) limit the dwellings a
#' site may have by the width of its access. A site with road frontage is
#' measured by its frontage. A rear site (less frontage than
#' `rear_site_max_frontage`, see [morphology_defaults()]) is usually reached
#' another way, and is measured here, following capacityengine (item 259):
#'
#' 1. **Its own entrance strip**: the longest stretch of its boundary on a
#'    road parcel, which reads a pan-handle's driveway more truly than the
#'    classified road segments do.
#' 2. **Easements** (`easements`, such as LINZ non-primary parcels of intent
#'    "Easement"): touching easement areas are dissolved into networks,
#'    because one right of way is often several surveyed areas of which one
#'    meets the road; a network's width is its longest stretch of road
#'    contact.
#' 3. **Access lots** (`other_parcels`, the other primary parcels): a parcel
#'    outside every site, smaller than `access_lot_max_area`, and strip-width
#'    where it meets the road; a jointly owned access lot can only be
#'    recognised by shape.
#'
#' Road contact wider than `access_max_strip_width` is a lot, not a strip, and
#' is ignored. Widths add only where a strip lies over adjoining land; an
#' easement over the site's own driveway is the same access counted twice and
#' combines by the larger. Pieces of one site split by a zone boundary take
#' the best access of any piece. A site where nothing is found has no
#' measurable access (`NA`): the access width table does not apply to it and
#' it is flagged, because titled land has legal access somewhere, often by a
#' right of way that predates digital survey.
#'
#' Easement layers rarely record what an easement is for, so a drainage
#' easement running to the street passes as a right of way: the measurement
#' can overstate.
#'
#' @param sites Sites, `sf` polygons with a `site_id` column.
#' @param roads Road parcels.
#' @param easements Optional easement areas.
#' @param other_parcels Optional other parcels (not roads), for access lots.
#' @param rulebook,morphology Morphology settings, as for [morphology].
#' @return A data frame: `site_id`, `frontage`, `is_rear`, `contact` (the
#'   entrance strip), `easement_width`, `access_lot_width`, `access_width`
#'   and `access_method` (`"frontage"`, `"entrance_strip"`, `"easement"`,
#'   `"access_lot"`, `"combination"`, `"sibling"` or `"none"`).
#' @export
#' @examples
#' town <- exampleton()
#' land <- town$parcels[town$parcels$parcel_type == "land", ]
#' names(land)[names(land) == "parcel_id"] <- "site_id"
#' acc <- find_access_widths(land, town$parcels[town$parcels$parcel_type == "road", ])
#' table(acc$access_method)
find_access_widths <- function(sites, roads, easements = NULL, other_parcels = NULL,
                               rulebook = NULL, morphology = list()) {
  pg <- parcel_geometry(sites, roads = roads, easements = easements, other_parcels = other_parcels,
                        rulebook = rulebook, morphology = morphology, legs = FALSE, widths = FALSE)
  sf::st_drop_geometry(pg$sites)[, c("site_id", "frontage", "is_rear", "access_contact",
                                     "easement_width", "access_lot_width", "access_width",
                                     "access_method")] |>
    stats::setNames(c("site_id", "frontage", "is_rear", "contact", "easement_width",
                      "access_lot_width", "access_width", "access_method"))
}

# The measurement, on geos geometry. `frontage` is the classified road
# frontage; returns a list of per-site vectors.
measure_access <- function(sg, frontage, rg, easements = NULL, other_parcels = NULL, m) {
  n <- length(sg)
  out <- list(contact = rep(0, n), easement = rep(0, n), lot = rep(0, n),
              width = frontage,
              method = ifelse(frontage > 0, "frontage", "none"))
  rear <- which(frontage < m$rear_site_max_frontage)
  if (!length(rear) || is.null(rg) || !length(rg)) return(finish_access(out))
  tol <- m$access_contact_tolerance
  touch <- m$access_touch_distance
  max_strip <- m$access_max_strip_width
  road_buf <- geos::geos_buffer(geos::geos_make_valid(rg), tol)
  road_tree <- geos::geos_strtree(road_buf)

  # The longest connected stretch of each geometry's boundary within `tol` of
  # a road, less the 2 x tol its ends run up the strip's sides, to the
  # centimetre.
  contact <- function(g) {
    if (!length(g)) return(numeric(0))
    b <- geos::geos_boundary(g)
    near <- geos::geos_strtree_query(road_tree, g)
    vapply(seq_along(g), function(i) {
      k <- near[[i]]
      if (!length(k)) return(0)
      k <- k[geos::geos_intersects(road_buf[k], g[i])]
      if (!length(k)) return(0)
      zone <- if (length(k) == 1L) road_buf[k] else geos::geos_unary_union(geos::geos_make_collection(road_buf[k]))
      parts <- geos::geos_unnest(geos::geos_line_merge(geos::geos_intersection(b[i], zone)), keep_multi = FALSE)
      if (!length(parts)) 0 else round(max(max(geos::geos_length(parts), 0) - 2 * tol, 0), 2)
    }, numeric(1))
  }
  strips <- function(g) {
    if (is.null(g) || !length(g)) return(NULL)
    w <- contact(g)
    ok <- w > 0.5 & w <= max_strip
    if (!any(ok)) return(NULL)
    list(geom = g[ok], width = w[ok])
  }
  rs <- sg[rear]
  reach <- function(st) {
    res <- list(width = rep(0, length(rear)), over = rep(FALSE, length(rear)))
    if (is.null(st)) return(res)
    rgb <- geos::geos_buffer(rs, touch)
    hits <- geos::geos_strtree_query(geos::geos_strtree(st$geom), rgb)
    for (i in seq_along(hits)) {
      k <- hits[[i]]
      if (!length(k)) next
      k <- k[geos::geos_intersects(st$geom[k], rgb[i])]
      if (!length(k)) next
      j <- k[which.max(st$width[k])]
      res$width[i] <- st$width[j]
      res$over[i] <- geos::geos_area(geos::geos_intersection(st$geom[j], rs[i])) > 5
    }
    res
  }

  own <- contact(rs)
  out$contact[rear] <- own
  own_strip <- pmax(frontage[rear], ifelse(own <= max_strip, own, 0))
  ease <- NULL
  if (!is.null(easements) && length(easements)) {
    # Grown by 5 cm so areas sharing a boundary dissolve, then shrunk back.
    net <- geos::geos_unnest(geos::geos_unary_union(geos::geos_make_collection(
      geos::geos_buffer(geos::geos_make_valid(easements), 0.05))), keep_multi = FALSE)
    net <- geos::geos_make_valid(geos::geos_buffer(net, -0.05))
    net <- net[!geos::geos_is_empty(net)]
    ease <- reach(strips(net))
  }
  lots <- NULL
  if (!is.null(other_parcels) && length(other_parcels)) {
    pg <- geos::geos_make_valid(other_parcels)
    pos <- geos::geos_point_on_surface(pg)
    inside <- geos::geos_strtree_query(geos::geos_strtree(sg), pos)
    in_site <- vapply(seq_along(pos), function(i) {
      k <- inside[[i]]
      length(k) > 0L && any(geos::geos_intersects(sg[k], pos[i]))
    }, logical(1))
    lots <- reach(strips(pg[!in_site & geos::geos_area(pg) < m$access_lot_max_area]))
  }
  e_w <- if (is.null(ease)) rep(0, length(rear)) else ease$width
  e_over <- if (is.null(ease)) rep(FALSE, length(rear)) else ease$over
  l_w <- if (is.null(lots)) rep(0, length(rear)) else lots$width
  out$easement[rear] <- e_w
  out$lot[rear] <- l_w
  adjoining <- pmax(ifelse(e_over, 0, e_w), l_w)
  out$width[rear] <- pmax(own_strip + adjoining, e_w)
  out$method[rear] <- ifelse(adjoining > 0 & own_strip > 0, "combination",
                      ifelse(l_w > 0 & l_w >= e_w, "access_lot",
                      ifelse(e_w > 0, "easement",
                      ifelse(own > frontage[rear] + 0.5, "entrance_strip",
                      ifelse(frontage[rear] > 0, "frontage", "none")))))
  finish_access(out)
}

# No measurable access is unknown, never zero.
finish_access <- function(out) {
  none <- is.na(out$width) | out$width < 0.5
  out$width[none] <- NA_real_
  out$method[none] <- "none"
  out
}

# Pieces of one landholding (split by a zone boundary, or named by the
# scenario's `landholding` column) share its best access.
inherit_access <- function(sites, rear_max) {
  if (!"access_width" %in% names(sites)) return(sites)
  grp <- sites$parent_id
  if ("landholding" %in% names(sites)) grp <- ifelse(is.na(sites$landholding), grp, sites$landholding)
  many <- grp %in% grp[duplicated(grp)]
  if (!any(many)) return(sites)
  best <- tapply(sites$access_width, grp, function(v)
    if (all(is.na(v))) NA_real_ else max(v, na.rm = TRUE))
  inh <- as.vector(best[grp])
  take <- many & sites$frontage < rear_max & !is.na(inh) &
    (is.na(sites$access_width) | inh > sites$access_width)
  sites$access_width[take] <- inh[take]
  sites$access_method[take] <- "sibling"
  sites
}

# A boundary's class on the ground: a rear site's side boundary reclassified
# as rear for its yards is a side boundary.
ground_class <- function(seg) {
  cls <- seg$boundary_class
  rs <- grepl("|rear_site_side|", seg$tags %||% rep("|", length(cls)), fixed = TRUE)
  cls[rs] <- "side"
  cls
}
