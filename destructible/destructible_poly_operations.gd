class_name DestructiblePolyOperations extends Node

@export_category("Smoothing")
@export var smooth_y_threshold_pct: float = 0.5

@export_category("Smoothing")
# Sometimes the algorithm flags things incorrectly that are essentially vertical drops near the left of screen
@export_range(5.0, 1e9, 1.0, "or_greater") var smooth_x_threshold_diff: float = 10

@export_category("Smoothing")
@export_range(0.0, 1.0, 0.01) var smooth_x_frac_deadzone: float = 0.1

@export_category("Crumbling")
@export var crumble_y_min_dist: float = 1

@export_category("Crumbling")
@export var crumble_x_min_dist: float = 50

@export_category("Crumbling")
@export var crack_delta_min: float = 5

@export_category("Crumbling")
@export var crack_delta_max: float = 25

@export_category("Crumbling")
@export_range(0, 100) var crumble_y_step_min: float = 5

@export_category("Crumbling")
@export_range(0, 100) var crumble_y_step_max: float = 50

@export_category("Crumbling")
@export_range(0, 100) var crumble_x_jitter: float = 10

@export_category("Shatter")
@export_range(0, 100) var max_iterations: int = 5

@export_category("Shatter")
@export_range(0, 0.2, 0.01) var min_subdivide_deviation: float = 0.0

@export_category("Shatter")
@export_range(0, 0.3, 0.01) var max_subdivide_deviation: float = 0.15

@export_category("Shatter")
@export_range(0, 100, 0.1) var absolute_min_area: float = 50.0

func smooth(poly: PackedVector2Array, bounds: Circle) -> PackedVector2Array:
	if poly.size() < 3:
		return poly

	# Polygon is actually stored clockwise. Look at vertices and see where x decreases indicating a dent until we start winding around
	# Don't modify the interior of the terrain. Detect this by looking at the maximum y (bottom-most point)
	var bottom_y: float = -1e12
	var top_y: float = 1e12
	for vec in poly:
		if vec.y > bottom_y : bottom_y = vec.y
		elif vec.y < top_y : top_y = vec.y
	var threshold_y: float = (bottom_y - top_y) * smooth_y_threshold_pct + bottom_y
	
	var smooth_updates: int = 0
 	
	var out_poly:PackedVector2Array
	out_poly.resize(poly.size())

	var j:int = 1
	for i in range(1, poly.size()):
		var current := poly[i]
		var prev := poly[i - 1]

		out_poly[j - 1] = prev

		# Don't modify the bottom
		if current.x - prev.x < -smooth_x_threshold_diff and current.y < prev.y and current.y < threshold_y and bounds.contains(current):

			var x_diff: float = current.x - prev.x
			var new_vertex_count:int = int(-x_diff / smooth_x_threshold_diff)

			out_poly.resize(out_poly.size() + new_vertex_count)
			var last_vertex: Vector2 = prev
			for k in range(new_vertex_count):
				var new_vertex: Vector2 = Vector2(
					lerpf(last_vertex.x, prev.x - smooth_x_threshold_diff * (k + 1), randf_range(smooth_x_frac_deadzone, 1.0 - smooth_x_frac_deadzone)),
					lerpf(prev.y, current.y, randf())
				)
				out_poly[j] = new_vertex
				last_vertex = new_vertex
				j += 1
				smooth_updates += 1
		j += 1

	# Assign last one
	out_poly[j - 1] = poly[poly.size() - 1]
	
	if smooth_updates:
		print_debug("Chunk(%s) - smooth: Changed %d vertices" % [get_parent().name, smooth_updates])

	# out_poly could be self-intersecting so check this
	if TerrainUtils.is_visible_polygon(out_poly):
		return out_poly

	push_warning("Chunk(%s) - smooth: Polygon is self-intersecting - returning original" % [get_parent().name])
	TerrainUtils.print_poly("DestructiblePolyOperations(%s) - smooth(INVALID):" % [get_parent().name], poly)

	return poly

# Always returns at least the input poly chunk in the returned array
func crumble(poly: PackedVector2Array, bounds: Circle) -> Array[PackedVector2Array]:
	var final_chunk_polys: Array[PackedVector2Array] = []
	
	var x_sum:float = 0.0
	var first_hanging:int = 0
	var hanging_count:int = 0
	
	for i in range(1, poly.size()):
		var vertex := poly[i]
		# We've gone outside the influence area - reset and try next vertex
		var vertex_hanging:bool = true
		if !bounds.contains(vertex):
			vertex_hanging = false
		# Determine if current vertex is at the bottom or top of chunk by checking small y offset to see if it is inside
		elif Geometry2D.is_point_in_polygon(vertex + Vector2(0, crumble_y_min_dist), poly):
			vertex_hanging = false	
		
		if vertex_hanging:
			x_sum += absf(poly[i].x - poly[i - 1 if i > 0 else poly.size() - 1].x)
			if hanging_count == 0:
				hanging_count = 1
				first_hanging = i
			else:
				hanging_count += 1
			
		# We've stopped hanging or on last vertex, check to see if we can cut a chunk
		# TODO: Maybe take thickness into account
		if (!vertex_hanging or i == poly.size() - 1) and hanging_count > 0 and x_sum >= crumble_x_min_dist:
			# Cut a jagged polygon up through the first hanging point and add the results when > 1 to output
			# Keep largest piece on this chunk?
			var crumble_chunks := _calculate_crumble(poly, first_hanging, hanging_count)
			# TODO: Need to break here or things get too complex if need to break it multiple times in one go
			if crumble_chunks.size() > 1:
				final_chunk_polys.append_array(crumble_chunks)
				break
				
		if !vertex_hanging:
			hanging_count = 0
			x_sum = 0.0
	# for
	
	if final_chunk_polys.is_empty():	
		final_chunk_polys.push_back(poly)
		
	return final_chunk_polys

func _calculate_crumble(poly: PackedVector2Array, first_index: int, count: int) -> Array[PackedVector2Array]:

	print_debug("Chunk(%s) - poly=%d; first_index=%d; count=%d" % [get_parent().name, poly.size(), first_index, count])

	# See https://forum.godotengine.org/t/cut-a-polygon-with-a-polyline-not-the-contrary/17710/3
	# See https://github.com/goostengine/goost/discussions/132
	var polyline := _create_break_polyline(poly, first_index)
	
	# Restrict to poly
	#var results := Geometry2D.clip_polyline_with_polygon(polyline, poly)
	#if results.is_empty():
	#	return []
	#polyline = results[0]
	
	var crack_delta: float = randf_range(crack_delta_min, crack_delta_max)
	var polygon_cut := Geometry2D.offset_polyline(polyline, crack_delta, Geometry2D.JOIN_SQUARE)
	if polygon_cut.is_empty():
		print_debug("Chunk(%s) - Could not crumble as polyline was invalid" % [get_parent().name])
		return []
	
	var clip_results := Geometry2D.clip_polygons(poly, polygon_cut[0])
	 
	print_debug("Chunk(%s) - raw clip result - %d:[%s]" % 
		[get_parent().name, clip_results.size(), ",".join(clip_results.map(func(c : PackedVector2Array): return c.size()))])

	clip_results = clip_results.filter(
		func(result:PackedVector2Array):
			return TerrainUtils.is_visible_polygon(result)
	)
	clip_results.sort_custom(TerrainUtils.largest_poly_first)
	
	print_debug("Chunk(%s) - final clip result - %d:[%s]" % 
	[get_parent().name, clip_results.size(), ",".join(clip_results.map(func(c : PackedVector2Array): return c.size()))])

	return clip_results
	
func _create_break_polyline(poly: PackedVector2Array, first_index: int) -> PackedVector2Array:
	var polyline: PackedVector2Array = []
	
	var viewport := (get_parent() as Node2D).get_viewport_rect()
		
	# Cut up through the first_index x and y with jitter applied
	# TODO: Can probably reduce the number of points here based on the world position of the poly
	# Right now the poly points are in local space
	var height = viewport.size.y * 0.5
	
	var first_point := poly[first_index]	
	var delta_y:float = 0
	var delta_point := Vector2(0, 1)
	
	while delta_y < height:
		polyline.push_back(first_point + delta_point)
		
		# Negate y to move up 
		var y_step: float = randf_range(crumble_y_step_min, crumble_y_step_max)
		delta_y += y_step
		
		delta_point = Vector2(
			randf_range(-crumble_x_jitter, crumble_x_jitter),
			-delta_y)
	
	return polyline

# Use Delaunay triangulation as a "confetti" shatter starting point since it creates a higher density mesh
# Then subdivide using centroids of the triangles to create smaller chunks and also combine some of the smaller adjacent triangle chunks together

func shatter(poly: PackedVector2Array, min_area: float, max_area: float) -> Array[PackedVector2Array]:
	if poly.size() < 3:
		return []
	if poly.size() == 3:
		return [poly]

	var points: PackedVector2Array = poly.duplicate()
	var last_point_count:int = 0
	var indices: PackedInt32Array = []
	for i in range(max_iterations):
		last_point_count = points.size()
		indices = Geometry2D.triangulate_delaunay(points)

		# If delaunay fails, then just break or return
		if indices.size() == 0:
			print_debug("body(%s-%s) - shatter: Delaunay triangulation failed" % [name, get_parent().name])
			if i == 0:
				push_warning("body(%s-%s) - shatter: Delaunay triangulation on original poly failed - returning empty array" % [name, get_parent().name])
				return []
			# Otherwise we can break if this isn't the first iteration
			break

		# Determine area of the triangles and if they are above the threshold, compute an offseted centroid
		for j in range(0, indices.size(), 3):
			var a: Vector2 = points[indices[j]]
			var b: Vector2 = points[indices[j + 1]]
			var c: Vector2 = points[indices[j + 2]]
			
			# Area of triangle
			var area: float = TerrainUtils.calculate_triangle_area(a, b, c)
			if area <= min_area:
				continue
			
			# Compute centroid to subdivide the triangle further but give it a deviation so that it isn't always the same
			var offset_centroid: Vector2 = _offset_centroid(a, b, c)
			points.append(offset_centroid)
		
		# We are done
		if last_point_count == points.size():
			break

	assert(indices.size() > 0, "body(%s-%s) - shatter: didn't exit out on delaunay failure!" % [name, get_parent().name])

	# Now that we have points and indices we can combine some adjacent triangles to make the chunks bigger
	var adjacent_indices: Array[PackedInt32Array] = TerrainUtils.get_all_adjacent_polygons(indices)
	var final_points: Array[PackedVector2Array] = []

	var added_points: Dictionary = {}
	var unique_indices: Dictionary = {}

	for i in range(adjacent_indices.size()):
		var triangle_indices: PackedInt32Array = adjacent_indices[i]
		var combined_area: float = 0.0
		var triangle_points: PackedVector2Array = []
		unique_indices.clear()

		for j in range(0, triangle_indices.size(), 3):
			var first_index: int = triangle_indices[j]
			if added_points.has(first_index):
				# Already accounted for the triangle and not just its adjacent neighbor
				if j == 0:
					break
				else:
					continue
			
			var second_index: int = triangle_indices[j + 1]
			var third_index: int = triangle_indices[j + 2]

			var a: Vector2 = points[first_index]
			var b: Vector2 = points[second_index]
			var c: Vector2 = points[third_index]

			var area: float = TerrainUtils.calculate_triangle_area(a, b, c)
			combined_area += area

			# Optimized case to not check the dictionary first time through
			if j == 0:
				triangle_points.append(a)
				triangle_points.append(b)
				triangle_points.append(c)

				unique_indices[first_index] = true
				unique_indices[second_index] = true
				unique_indices[third_index] = true

			elif combined_area < max_area:
				# Make sure we don't duplicate the points on the adjacent indices
				if first_index not in unique_indices:
					unique_indices[first_index] = true
					triangle_points.append(a)
				if second_index not in unique_indices:
					unique_indices[second_index] = true
					triangle_points.append(b)
				if third_index not in unique_indices:
					unique_indices[third_index] = true
			else:
				break

			added_points[first_index] = true
		
		if not triangle_points.is_empty():
			final_points.append(triangle_points)

	# Now we have the points and just need to turn them into polygons
	var poly_points_list: Array[PackedVector2Array] = [] 
	for i in range(final_points.size()):
		var poly_points: PackedVector2Array = _points_to_poly(final_points[i])
		# Make sure polygon isn't below threshold size
		if not poly_points.is_empty() and TerrainUtils.calculate_polygon_area(poly_points) >= absolute_min_area:
			poly_points_list.append(poly_points)

	return poly_points_list

# Offset the centroid of the triangle formed by p1, p2, and p3 so that the fracture isn't always predictable
# Doc calculations in barycentric coordinates for efficiency and to stay within triangle
func _offset_centroid(p1: Vector2, p2: Vector2, p3: Vector2) -> Vector2:
	# Centroid in barycentric coordinates
	var w1:float = 1 / 3.0
	var w2:float = w1
	var w3:float = w1

	# Apply small random offsets to the barycentric weights
	var offset1 := MathUtils.randf_range_signed(min_subdivide_deviation, max_subdivide_deviation)
	var offset2 := MathUtils.randf_range_signed(min_subdivide_deviation, max_subdivide_deviation)
	var offset3 := -offset1 - offset2  # Ensure weights sum to 1
	
	w1 += offset1
	w2 += offset2
	w3 += offset3

	# Normalize to ensure weights sum to 1
	var total := w1 + w2 + w3
	w1 /= total
	w2 /= total
	w3 /= total

	var min_weight: float = 1 / 3.0 - max_subdivide_deviation

	# Apply redistribution logic for weights below min_weight
	if w1 < min_weight:
		var deficit := min_weight - w1  # How much needs to be added
		var sum_other := w2 + w3
		if sum_other > 0.0:  # Redistribute only if the denominator is valid
			w2 -= deficit * (w2 / sum_other)
			w3 -= deficit * (w3 / sum_other)
		w1 = min_weight
	if w2 < min_weight:
		var deficit := min_weight - w2
		var sum_other := w1 + w3
		if sum_other > 0.0:
			w1 -= deficit * (w1 / sum_other)
			w3 -= deficit * (w3 / sum_other)
		w2 = min_weight
	if w3 < min_weight:
		var deficit := min_weight - w3
		var sum_other := w1 + w2
		if sum_other > 0.0:
			w1 -= deficit * (w1 / sum_other)
			w2 -= deficit * (w2 / sum_other)
		w3 = min_weight

	# Check to make sure still inside triangle and fallback to centroid if not
	if not TerrainUtils.is_inside_triange_barycentric(w1, w2, w3):
		print_debug("body(%s-%s) - shatter: barycentric weights out of bounds: w1=%f;w2=%f;w3=%f - using centroid" % [name, get_parent().name, w1, w2, w3])
		w1 = 1 / 3.0
		w2 = w1
		w3 = w1

	# Convert barycentric coordinates to Cartesian coordinates
	return TerrainUtils.barycentric_to_cartesian(w1, w2, w3, p1, p2, p3)

func _points_to_poly(points: PackedVector2Array) -> PackedVector2Array:
	# Use a convex hull to create polygon from points
	return Geometry2D.convex_hull(points)
