class_name PolygonPruner extends Node

@export_range(1.0, 20.0, 0.01) var max_distance:float = 5.0
@export var require_threshold_all_neighbors:bool = false

func prune_polygons(polygons:PackedVector2Array) -> PackedVector2Array:
	if polygons.size() <= 3:
		return polygons
	
	var max_dist_sq:float = max_distance * max_distance	
	var retained_indices:PackedByteArray = []
	retained_indices.resize(polygons.size())
	retained_indices.fill(1)
	
	var pruned_count:int = 0
	
	for i in range(2, polygons.size(), 1):
		var ai:int = i - 2
		var bi:int = i - 1
		var a:Vector2 = polygons[ai]
		var b:Vector2 = polygons[bi]
		var c:Vector2 = polygons[i]

		var passed:bool = a.distance_squared_to(b) < max_dist_sq
		if not passed and require_threshold_all_neighbors:
			continue
		if (passed and not require_threshold_all_neighbors) or b.distance_squared_to(c) < max_dist_sq:
			pruned_count += 1
			retained_indices[bi] = 0
			# Skip past removed
			i += 1
	
	if pruned_count == 0:
		print_debug("%s(%s): 0 polygons pruned - size=%d" % [name, get_parent().name, polygons.size()])
		return polygons

	var retained_polygons:PackedVector2Array = []
	retained_polygons.resize(polygons.size() - pruned_count)

	var count:int = 0
	for i in retained_indices.size():
		var retained:bool = retained_indices[i]
		if retained:
			retained_polygons[count] = polygons[i]
			count += 1

	print_debug("%s(%s): %d polygons pruned - size=%d -> %d" % [name, get_parent().name, pruned_count, polygons.size(), retained_polygons.size()])
	return retained_polygons
