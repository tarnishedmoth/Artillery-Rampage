class_name TerrainUtils

static func largest_poly_first(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return a.size() > b.size()
	
static func is_invisible(poly: PackedVector2Array) -> bool:
	return poly.size() < 3 or Geometry2D.is_polygon_clockwise(poly)

static func is_visible(poly: PackedVector2Array) -> bool:
	return !is_invisible(poly)

# Calculate the area of a triangle using the Shoelace formula
static func calculate_triangle_area(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	var area = 0.5 * abs(
		p1.x * (p2.y - p3.y) +
		p2.x * (p3.y - p1.y) +
		p3.x * (p1.y - p2.y)
	)
	return area
	
# Calculate the area of a polygon using the Shoelace formula
static func calculate_polygon_area(polygon: PackedVector2Array) -> float:
	var area = 0.0
	var n = polygon.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	
	area = abs(area) * 0.5
	return area

static func determine_overlap_vertices(first_poly: PackedVector2Array, second_poly: PackedVector2Array, association_dist: float, overlap_dist: float) -> Array[PackedInt32Array]:
	var assoc_dist_sq := association_dist * association_dist
	var overlap_dist_sq := overlap_dist * overlap_dist
	
	return [
		_determine_source_overlaps_target_vertices(first_poly, second_poly, assoc_dist_sq, overlap_dist_sq),
		_determine_source_overlaps_target_vertices(second_poly, first_poly, assoc_dist_sq, overlap_dist_sq)
	]

static func _determine_source_overlaps_target_vertices(source_poly: PackedVector2Array, target_poly: PackedVector2Array, association_dist_sq: float, overlap_dist_sq: float) -> PackedInt32Array:
	var all_results : PackedInt32Array = []
	var direct_results: Dictionary = {}
	
	for i in range(0, source_poly.size()):
		var vertex := source_poly[i]
		# TODO: Do we need to check left and right too?
		var pos_down: Vector2 = Vector2(vertex.x, vertex.y + overlap_dist_sq)
		var pos_up: Vector2 =  Vector2(vertex.x, vertex.y - overlap_dist_sq)
		if Geometry2D.is_point_in_polygon(pos_down, target_poly) or Geometry2D.is_point_in_polygon(pos_up, target_poly):
			direct_results[i] = true
			all_results.push_back(i)
	
	# Now look for other vertices nearby to those that are directly near the target polygon
	for i in range(0, source_poly.size()):
		if direct_results.get(i):
			continue
		var vertex := source_poly[i]
		for contained_index in direct_results:
			var dist_sq := vertex.distance_squared_to(source_poly[contained_index])
			if dist_sq <= association_dist_sq:
				all_results.push_back(i)
	return all_results
	
static func prune_small_area_poly(poly: PackedVector2Array, pruning_index_candidates: PackedInt32Array, threshold_area: float) -> void:
	if !pruning_index_candidates:
		return
	
	# each triangle consists of three consecutive point indices into polygon (i.e. the returned array will have n * 3 elements, 
	# with n being the number of found triangles). Output triangles will always be counter clockwise, 
	# and the contour will be flipped if it's clockwise. If the triangulation did not succeed, an empty PackedInt32Array is returned.
	var triangle_list_indices : PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	
	if !triangle_list_indices:	
		push_warning("prune_small_area_poly: Unable to triangulate poly with size=%d" % [poly.size()])
		return
		
	var removal_indices: PackedInt32Array = []
	
	for index in pruning_index_candidates:
		# Check that all triangles that are involved
		if is_exclusive_small_area_poly_index(triangle_list_indices, poly, index, threshold_area):
			removal_indices.push_back(index)
	
	if OS.is_debug_build():
		var values: Array[int] = []
		for index in removal_indices:
			values.push_back(index)
		print_debug("poly size=%d, pruning(%d)=%s" % [poly.size(), values.size(), ",".join(values.map(func(idx : int): return str(idx)))])
		
	for index in removal_indices:
		poly.remove_at(index)
	
static func is_exclusive_small_area_poly_index(triangle_list_indices: PackedInt32Array, poly: PackedVector2Array, index: int, threshold_area: float) -> bool:
	# Check that all triangles that are involved with the index meet the threshold_area
	var search_index: int = 0
	
	var triangle_indices: PackedInt32Array = [0, 0, 0]
	
	while search_index < triangle_list_indices.size():
		search_index = triangle_list_indices.find(index, search_index)
		if search_index == -1:
			break
		
		# Need to test the triangle area and immediately return false if the triangle its involved in is larger than the threshold area
		match search_index % 3:
			0:
				triangle_indices[0] = triangle_list_indices[search_index]
				triangle_indices[1] = triangle_list_indices[search_index + 1]
				triangle_indices[2] = triangle_list_indices[search_index + 2]
			1:
				triangle_indices[0] = triangle_list_indices[search_index - 1]
				triangle_indices[1] = triangle_list_indices[search_index]
				triangle_indices[2] = triangle_list_indices[search_index + 1]
			_: # 2
				triangle_indices[0] = triangle_list_indices[search_index - 2]
				triangle_indices[1] = triangle_list_indices[search_index - 1]
				triangle_indices[2] = triangle_list_indices[search_index]
				
		var area := calculate_triangle_area(poly[triangle_indices[0]], poly[triangle_indices[1]], poly[triangle_indices[2]])
		if area >= threshold_area:
			return false
		# Start the find from next vertex
		search_index += 1
	# All areas the index is involved in are less than threshold area or it dosen't have a triangle all
	return true
