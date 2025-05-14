## Base class for shatter algorithm to use for DestructiblePolyOperations.Shatter
class_name ShatterStrategy extends Node

var log_context_node:Node

func _ready() -> void:
	# Body is attached two levels up 
	var parent:Node = get_parent()
	if parent:
		log_context_node = parent.get_parent()
		if not log_context_node:
			log_context_node = parent
	else:
		log_context_node = self

func shatter(_poly: PackedVector2Array, _min_area: float, _max_area: float) -> Array[PackedVector2Array]:
	push_error("body(%s-%s) - shatter not overridden in derived class!" % [name, log_context_node.name])
	return []

func _points_to_poly(points: PackedVector2Array) -> PackedVector2Array:
	# Use a convex hull to create polygon from points
	return Geometry2D.convex_hull(points)
