extends Node

static func largest_poly_first(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return a.size() > b.size()
	
static func is_invisible(poly: PackedVector2Array) -> bool:
	return poly.size() < 3 or Geometry2D.is_polygon_clockwise(poly)

static func is_visible(poly: PackedVector2Array) -> bool:
	return !is_invisible(poly)
