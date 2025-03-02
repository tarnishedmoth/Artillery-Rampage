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

# Triangulate always produces counter clockwise triangles so can simplify the checks

static func is_adjacent_triangle(i00: int, i01: int, i02: int, i10: int, i11: int, i12: int) -> bool:
	# Need exactly two vertices to be the same as they need to share a common edge
	return ((i00 == i10 and i01 == i11) or (i00 == i11 and i01 == i12) or (i00 == i12 and i01 == i10) or
			(i01 == i10 and i02 == i11) or (i01 == i11 and i02 == i12) or (i01 == i12 and i02 == i10) or
			(i02 == i10 and i00 == i11) or (i02 == i11 and i00 == i12) or (i02 == i12 and i00 == i10)) and \
			!is_same_triangle(i00, i01, i02, i10, i11, i12)

static func is_same_triangle(i00: int, i01: int, i02: int, i10: int, i11: int, i12: int) -> bool:
	return i00 == i10 and i01 == i11 and i02 == i12

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
		if direct_results.has(i):
			continue
		var vertex := source_poly[i]
		for contained_index in direct_results:
			var dist_sq := vertex.distance_squared_to(source_poly[contained_index])
			if dist_sq <= association_dist_sq:
				all_results.push_back(i)

	if OS.is_debug_build():
		var values: Array[int] = []
		for index in all_results:
			values.push_back(index)
		print_debug("determine_overlap_vertices: source(%d), target(%d), results=%d - %s" 
		% [source_poly.size(), target_poly.size(), all_results.size(), ",".join(values.map(func(idx : int): return str(idx)))])
	
	return all_results
	
static func prune_small_area_poly(poly: PackedVector2Array, pruning_index_candidates: PackedInt32Array, threshold_area: float) -> int:
	if !pruning_index_candidates:
		return 0
	
	# each triangle consists of three consecutive point indices into polygon (i.e. the returned array will have n * 3 elements, 
	# with n being the number of found triangles). Output triangles will always be counter clockwise, 
	# and the contour will be flipped if it's clockwise. If the triangulation did not succeed, an empty PackedInt32Array is returned.
	var triangle_list_indices : PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	
	if !triangle_list_indices:	
		push_warning("prune_small_area_poly: Unable to triangulate poly with size=%d" % [poly.size()])
		return 0
		
	var removal_indices: PackedInt32Array = []
	
	for index in pruning_index_candidates:
		# Check that all triangles that are involved
		if is_exclusive_small_area_poly_index(triangle_list_indices, poly, index, threshold_area):
			removal_indices.push_back(index)
	
	if OS.is_debug_build():
		var values: Array[int] = []
		for index in removal_indices:
			values.push_back(index)
		print_debug("poly size=%d, raw pruning(%d)=%s" % [poly.size(), values.size(), ",".join(values.map(func(idx : int): return str(idx)))])
	
	# Need to combine areas of adjacent triangles
	# Since removing from array iterate in reverse as it is more efficient
	# TODO: Uncomment once had a chance to test as this code is pretty crazy
	# removal_indices = _get_pruned_isolated_vertices(poly, triangle_list_indices, removal_indices)

	# if OS.is_debug_build():
	# 	var values: Array[int] = []
	# 	for index in removal_indices:
	# 		values.push_back(index)
	# 	print_debug("poly size=%d, final pruning(%d)=%s" % [poly.size(), values.size(), ",".join(values.map(func(idx : int): return str(idx)))])
		

	for index in range(removal_indices.size() - 1, -1, -1):
		poly.remove_at(index)
	
	return removal_indices.size()


static func _get_all_triangles(triangle_list_indices: PackedInt32Array, indices: PackedInt32Array) -> PackedInt32Array:
	var all_triangles: PackedInt32Array = []
	
	for index in indices:
		var search_index: int = 0
		while search_index < triangle_list_indices.size():
			search_index = triangle_list_indices.find(index, search_index)
			if search_index == -1:
				break
			
			# The triangle list packs the indices in groups of 3
			var triangle_index := search_index % 3
			match triangle_index:
				0:
					all_triangles.push_back(triangle_list_indices[search_index])
					all_triangles.push_back(triangle_list_indices[search_index + 1])
					all_triangles.push_back(triangle_list_indices[search_index + 2])
				1:
					all_triangles.push_back(triangle_list_indices[search_index - 1])
					all_triangles.push_back(triangle_list_indices[search_index])
					all_triangles.push_back(triangle_list_indices[search_index + 1])
				_: # 2
					all_triangles.push_back(triangle_list_indices[search_index - 2])
					all_triangles.push_back(triangle_list_indices[search_index - 1])
					all_triangles.push_back(triangle_list_indices[search_index])
			
			# Start the find from next triangle group
			search_index += 3 - triangle_index
	
	return all_triangles

static func _get_pruned_isolated_vertices(poly: PackedVector2Array, triangle_list_indices: PackedInt32Array, candidate_indices: PackedInt32Array) -> PackedInt32Array:
	
	if(candidate_indices.is_empty()):
		return candidate_indices

	var candidate_indices_list := _get_all_triangles(triangle_list_indices, candidate_indices)

	var adjacent_triangles: Array[PackedInt32Array] = get_all_adjacent_polygons(candidate_indices_list)

	adjacent_triangles = _collapse_adjacent_triangles(adjacent_triangles)

	var final_indices: PackedInt32Array = []
	for index in candidate_indices:
		for component in adjacent_triangles:
			if component.has(index):
				final_indices.push_back(index)
				break

	return final_indices

static func _prune_large_area_connected_components(poly: PackedVector2Array, components: Array[PackedInt32Array], threshold_area: float) -> Array[PackedInt32Array]:
	var pruned_components: Array[PackedInt32Array] = []
	
	for component in components:
		var area_sum: float = 0.0
		for i in range(0, component.size(), 3):
			var area : float = calculate_triangle_area(poly[component[i]], poly[component[i + 1]], poly[component[i + 2]])
			area_sum += area
		if area_sum < threshold_area:
			pruned_components.push_back(component)
	
	return pruned_components

# TODO: This is kind of madness - maybe just create a tuple class to hold the indices
# Also, can cache the area of triangle already computed and hide that behind a separate abstraction

static func get_all_adjacent_polygons(triangle_list_indices: PackedInt32Array) -> Array[PackedInt32Array]:
	var all_adjacent: Array[PackedInt32Array] = []
	
	var triangle_indices: PackedInt32Array = [0, 0, 0]

	for i in range(0, triangle_list_indices.size(), 3):
		triangle_indices[0] = triangle_list_indices[i]
		triangle_indices[1] = triangle_list_indices[i + 1]
		triangle_indices[2] = triangle_list_indices[i + 2]

		var adjacent: PackedInt32Array = []
		for j in range(0, triangle_list_indices.size(), 3):
			if i == j:
				continue
			
			if is_adjacent_triangle(triangle_indices[0], triangle_indices[1], triangle_indices[2],
			 		triangle_list_indices[j], triangle_list_indices[j + 1], triangle_list_indices[j + 2]):
				if adjacent.is_empty():
					adjacent.push_back(i)
					adjacent.push_back(i + 1)
					adjacent.push_back(i + 2)
				adjacent.push_back(j)
				adjacent.push_back(j + 1)
				adjacent.push_back(j + 2)

				# Can only have 3 adjacent triangles as only three edges + the original "node" triangle so 12 indices
				if adjacent.size() == 12:
					break
		
		if(!adjacent.is_empty()):
			all_adjacent.push_back(adjacent)
	# Want to combine contiguous adjacent triangles
	# Treat the arrays as a graph and need to find the spanning forests

	return all_adjacent	

static func _collapse_adjacent_triangles(nodes_edges : Array[PackedInt32Array]) -> Array[PackedInt32Array]:
	var components: Array[PackedInt32Array] = []
	
	var visited: Dictionary = {}
	var adjaceny_list_graph: Dictionary = _make_graph(nodes_edges)

	for node in adjaceny_list_graph:
		if visited.has(node):
			continue
		var comp := _dfs_adjacent_triangles(adjaceny_list_graph, node, visited)
		components.push_back(comp)
			
	return components

static func _make_graph(nodes_edges : Array[PackedInt32Array]) -> Dictionary:
	var adjacency_list_graph: Dictionary = {}

	for edge_list in nodes_edges:
		var node := _get_node_id(edge_list)
		adjacency_list_graph[node].append(edge_list)

	return adjacency_list_graph

static func _get_node_id_tri_indices(i0 : int, i1 : int, i2 : int) -> int:
	# combine to use the full range of int64 
	return i0 | (i1 << 21) | (i2 << 42)

static func _unpack_node_id_to_indices(node_id : int, index_array: PackedInt32Array) -> void:
	# 0x1FFFFF is a 21-bit mask
	var i0 := node_id & 0x1FFFFF
	var i1 := (node_id >> 21) & 0x1FFFFF
	var i2 := (node_id >> 42) & 0x1FFFFF
	index_array.push_back(i0)
	index_array.push_back(i1)
	index_array.push_back(i2)

static func _get_node_id(edge_list : PackedInt32Array) -> int:
	# First edge is actually the triangles of the node itself
	return _get_node_id_tri_indices(edge_list[0], edge_list[1], edge_list[2])

static func _dfs_adjacent_triangles(graph: Dictionary, node: int, visited: Dictionary) -> PackedInt32Array:
	var stack: Array[int] = []
	var component: PackedInt32Array = []
	
	stack.append(node)
	
	while stack.size() > 0:
		var current_node = stack.pop_back()
		
		if current_node not in visited:
			visited[current_node] = true
			_unpack_node_id_to_indices(current_node, component)
			
			var edge_list = graph[current_node]
			if !edge_list:
				continue
			# Node itself is the first triangle which is 0,1,2 in the PackedInt32Array
			for neighbor_index_start in range(3, edge_list.size(), 3):
				var neighbor = _get_node_id_tri_indices(
					edge_list[neighbor_index_start], edge_list[neighbor_index_start + 1], edge_list[neighbor_index_start + 2])
				if neighbor not in visited:
					stack.append(neighbor)
	return component

static func is_exclusive_small_area_poly_index(triangle_list_indices: PackedInt32Array, poly: PackedVector2Array, index: int, threshold_area: float) -> bool:
	# Check that all triangles that are involved with the index meet the threshold_area
	var search_index: int = 0
	var triangle_indices: PackedInt32Array = [0, 0, 0]
	
	while search_index < triangle_list_indices.size():
		search_index = triangle_list_indices.find(index, search_index)
		if search_index == -1:
			break
		
		# Need to test the triangle area and immediately return false if the triangle its involved in is larger than the threshold area
		# The triangle list packs the indices in groups of 3
		var triangle_index := search_index % 3
		match triangle_index:
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

		print_debug("is_exclusive_small_area_poly_index: index=%d (%d,%d,%d) -> [%s,%s,%s], area=%f -> %s" 
			% [index, triangle_indices[0], triangle_indices[1], triangle_indices[2],
			 str(poly[triangle_indices[0]]), str(poly[triangle_indices[1]]), str(poly[triangle_indices[2]]), area, str(area < threshold_area)])

		if area >= threshold_area:
			return false
		# Start the find from next triangle group
		search_index += 3 - triangle_index
	# All areas the index is involved in are less than threshold area or it dosen't have a triangle all
	return true
