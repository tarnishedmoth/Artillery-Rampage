class_name ProceduralTerrainModifier extends Node2D

@export var noise_template : FastNoiseLite
@export var randomize_seed:bool = true

## Set to restrict the terrain modification to start at the given position
@export var start_at:Node2D
## Set to end the terrain modification at given position. Leave empty to modify to the end
@export var stop_at:Node2D 

@export_category("Generation")
## Specify additional vertices to add evenly between the modification bounds
@export_range(0, 1000) var additional_vertices:int = 0
# TODO: May want to have a parameter for vertex density

@export_category("Generation")
## Set to true to completely replace existing height data in terrain and re-generate within min and max values.
@export var replace_existing_heights:bool = false

@export_category("Generation")
## Controls how far up from the current height we will deviate
## Should be negative to raise the terrain up [-1,1]
@export_range(-1,1,0.001) var height_win_size_min_variation:float = -0.1


@export_category("Generation")
## Controls how far down from the current height we will deviate
## Should be positive to push the terrain down [-1,1]
@export_range(-1,1,0.001) var height_win_size_max_variation:float = 0.1

@export_category("Generation")
## Minimum height value from bottom of terrain value for min terrain height
@export_range(0,600,0.01) var min_height_value:float = 20

@export_category("Generation")
## Minimum height value from top of viewport for max terrain height
@export_range(0,700,0.01) var max_height_clearance:float = 50

@export_category("Generation")
## Consistency in spacing of new terrain points.  Set to 1 for equal placement
## and a lower value for a more random distribution.
@export_range(0.1, 1, 0.01) var consistency:float = 0.5

var _noise: FastNoiseLite
var _terrain: Terrain

func _ready() -> void:
	_terrain = get_parent() as Terrain
	if !_terrain:
		push_error("ProceduralTerrainModifier(%s) must be added as a child of Terrain but found %s" % [name, get_parent()])
		return
	
	_noise = _generate_noise()
	_modify_terrain()

func _modify_terrain():
	# TODO: The original implementation uses the viewport_rect rather than the terrain global bounds
	var terrain_bounds := _terrain.get_viewport_rect()
	#var terrain_bounds := _terrain.get_bounds_global()
	# Vertices will only be added or modified in given bounds
	var modification_bounds := _get_modification_bounds_global(terrain_bounds)

	for chunk in _terrain.get_chunks():
		var terrain_chunk := chunk as TerrainChunk
		if terrain_chunk:
			_modify_chunk(terrain_chunk, terrain_bounds, modification_bounds)

func _get_modification_bounds_global(full_bounds:Rect2) -> Rect2:
	var bounds:Rect2 = full_bounds
	if start_at:
		bounds.position.x = start_at.global_position.x
	#else we start at the default position

	if stop_at:
		bounds.size.x = stop_at.global_position.x - bounds.position.x
	elif start_at: # Extend to the viewport
		bounds.size.x = full_bounds.size.x - (start_at.global_position.x - full_bounds.position.x)
	# Y position and size is same as full_bounds

	return bounds

func _vertex_in_bounds(vertex:Vector2) -> bool:
	# Check if x coordinate in bounds if this modifier has a start x
	if start_at:
		#if vertex.x < bounds.position.x:
		if vertex.x < start_at.global_position.x:
			return false
	if stop_at:
		#if vertex.x > bounds.position.x + bounds.size.x:
		if vertex.x > stop_at.global_position.x:
			return false
	return true

func _get_interpolated_start_point(prev_point:Vector2, _next_point:Vector2, modification_bounds:Rect2) -> Vector2:
	var clamped_prev_point:Vector2
	clamped_prev_point.x = modification_bounds.position.x
	# We end up just overwriting the y
	clamped_prev_point.y = prev_point.y
	#clamped_prev_point.y = lerpf(prev_point.y, next_point.y, (clamped_prev_point.x - prev_point.x) / (next_point.x - prev_point.x))
	return clamped_prev_point

func _get_interpolated_end_point(prev_point:Vector2, next_point:Vector2, modification_bounds:Rect2) -> Vector2:
	var clamped_next_point:Vector2
	clamped_next_point.x = modification_bounds.position.x + modification_bounds.size.x
	clamped_next_point.y = lerpf(prev_point.y, next_point.y, (clamped_next_point.x - prev_point.x) / (next_point.x - prev_point.x))
	return clamped_next_point
		
func _modify_chunk(chunk: TerrainChunk, terrain_bounds:Rect2, modification_bounds: Rect2) -> void:
	var min_height := max_height_clearance
	var max_height := modification_bounds.size.y - min_height_value
	var height_range := max_height - min_height
	var terrain_vertices : PackedVector2Array = chunk.get_terrain_global()

	var min_variation := height_range * height_win_size_min_variation
	var max_variation := height_range * height_win_size_max_variation
	
	print_debug("ProceduralTerrainModifier(%s): chunk=%s; height=[%f,%f]; terrain_vertices(%d); min_variation=%f; max_variation=%f" %
	[
		name,
		chunk.name,
		min_height,
		max_height,
		terrain_vertices.size(),
		min_variation,
		max_variation
	])
	
	var new_terrain:bool = false
	
	if terrain_vertices.is_empty():
		new_terrain = true
		_seed_terrain(terrain_vertices, terrain_bounds, 4)
		assert(not terrain_vertices.is_empty(), "Seed Terrain did not add any vertices")
		chunk.replace_contents(terrain_vertices, [], TerrainChunk.UpdateFlags.Immediate)
		
	var first_non_surface_index:int = _get_first_non_surface_index(chunk, terrain_vertices)
			
	# First modify any existing points or the original terrain points if new terrain
	var vertices_in_bounds:int = 0
	
	#region existing terrain
	for i in first_non_surface_index:
		var vertex := terrain_vertices[i]

		# Only modify exterior vertices
		if not _vertex_in_bounds(vertex):
			continue
		
		vertices_in_bounds += 1

		var raw_height_fract := _sample_height_frac(vertex.x)

		var new_height:float
		if replace_existing_heights:
			new_height = lerpf(min_height, max_height, raw_height_fract)
		else:
			new_height = clampf(
				lerpf(vertex.y + min_variation, vertex.y + max_variation, raw_height_fract),
				min_height,
				max_height
			)
		terrain_vertices[i].y = new_height
#endregion
#region new terrain
	# Now add additional vertices requested
	var new_terrain_vertices:PackedVector2Array = []
	
	if additional_vertices > 0:
		var total_vertices:int = vertices_in_bounds + additional_vertices
		var ideal_spacing:float = modification_bounds.size.x / total_vertices
				
		var vertices_remaining := additional_vertices		
		var last_added_index:int = -1
		
		for i in first_non_surface_index:
			var curr_point:Vector2 = terrain_vertices[i]
			var curr_point_in_bounds:bool = _vertex_in_bounds(curr_point)

			# Guaranteed to be at least one more point since we stop at the interior vertices
			var next_point:Vector2 = terrain_vertices[i + 1]
			var next_point_in_bounds:bool = _vertex_in_bounds(next_point)	

			if not curr_point_in_bounds:
				last_added_index = i
				new_terrain_vertices.push_back(curr_point)
				
				# Interpolate point at start boundary
				if next_point_in_bounds:
					curr_point = _get_interpolated_start_point(curr_point, next_point, modification_bounds)
				else:
					continue

			if not next_point_in_bounds:
				next_point = _get_interpolated_end_point(curr_point, next_point, modification_bounds)
				
			var total_to_add:int = mini(
				int(next_point.distance_to(curr_point) / ideal_spacing), vertices_remaining)
			
			if total_to_add == 0:
				print_debug("ProceduralTerrainModifier(%s): chunk=%s; vertex[%d]=%s- total_to_add=0" % [name, chunk.name, i, str(curr_point)])
				continue
			
			last_added_index = i
			new_terrain_vertices.push_back(curr_point)
						
			var direction:float = signf(next_point.x - curr_point.x)
			var ideal_height_inc: float = (next_point.y - curr_point.y) / total_to_add
			var min_x = minf(curr_point.x, next_point.x)
			var max_x = maxf(curr_point.x, next_point.x)
			
			var added_count:int = 0
			var last_point:Vector2 = curr_point
			
			for j in total_to_add:
				var x:float = last_point.x + direction * randf_range(ideal_spacing * consistency, ideal_spacing / consistency)
				if x <= min_x or x >= max_x:
					break
				var raw_height_frac:float = _sample_height_frac(x)
				var y:float = clampf(
					lerpf(last_point.y + min_variation, last_point.y + max_variation,
					 raw_height_frac),
					min_height,
					max_height
				)
				
				var new_point := Vector2(x,y)
				
				# Smooth out first point, which was last point added before the new vertices
				if j == 0:
					new_terrain_vertices[-1].y = new_point.y
				
				new_terrain_vertices.push_back(new_point)
				
				added_count += 1

				if !new_terrain:
					# Smooth out to head toward next point
					var smooth_height:float = last_point.y + ideal_height_inc * j
					last_point = Vector2(x, (y + smooth_height) * 0.5)
				else:
					last_point = new_point
			# end for total_to_add
				
			vertices_remaining -= added_count
			
			print_debug("ProceduralTerrainModifier(%s): chunk=%s; vertex[%d]=%s->%s- total_to_add=%d; added_count=%d; vertices_remaining=%d" \
				% [name, chunk.name, i,  str(curr_point), str(next_point), total_to_add, added_count, vertices_remaining])

			if vertices_remaining <= 0:
				break
		# end for all terrain_vertices

		# Add in the non surface points and any unprocessed original points
		var should_smooth_end_points:bool = start_at and not stop_at
		var should_smooth_last_added_point:bool = should_smooth_end_points or (not start_at and not stop_at)
		
		# Extra smoothing on right edge - the last point tends to slope down to the default value (terrain_vertices[first_non_surface_index - 1])
		# This reduces chance of a big falloff on right side of map
		if should_smooth_last_added_point and new_terrain_vertices.size() > 1:
			new_terrain_vertices[-1].y = new_terrain_vertices[-2].y
			terrain_vertices[first_non_surface_index - 1].y = new_terrain_vertices[-1].y
		
		for i in range(mini(last_added_index + 1,first_non_surface_index), terrain_vertices.size()):
			# Smooth out final section of unprocessed points to have same height as last processed one
			# if i is 0 that means nothing was added and new_terrain_vertices would be empty and we skip that case too
			if should_smooth_end_points and i < first_non_surface_index and i > 0:
				terrain_vertices[i].y = new_terrain_vertices[-1].y
			new_terrain_vertices.push_back(terrain_vertices[i])
#endregion
	else:
		new_terrain_vertices = terrain_vertices
	
	# Update final terrain
	chunk.replace_contents(new_terrain_vertices)

func _get_first_non_surface_index(chunk: TerrainChunk, terrain_vertices: PackedVector2Array):
	# Because of winding order find the first vertex that is not on the surface and that starts the interior sequence
	var first_non_surface_index:int = terrain_vertices.size()
	# First point is the edge which is sometimes considered a non surface point but we want to get to the right
	for i in range(1, terrain_vertices.size()):
		var vertex:Vector2 = terrain_vertices[i]
		if not chunk.is_surface_point_global(vertex):
			first_non_surface_index = i
			break
	return first_non_surface_index

func _seed_terrain(terrain_vertices : PackedVector2Array, bounds: Rect2, count: int) -> void:
	var bottom_y:float = bounds.position.y + bounds.size.y
	var top_y:float = bottom_y - min_height_value
	
	# Half on top and half on the bottom in a rectangle
	var half_count: int = floori(count / 2.0)
	var stride: float = bounds.size.x / (half_count - 1)
	
	var populate_side: Callable = func(x: float, y: float, dir: float):
		var side_stride:float = dir * stride
		for i in half_count:
			terrain_vertices.push_back(Vector2(x, y))
			x += side_stride
	
	populate_side.call(bounds.position.x,  top_y, 1.0)
	populate_side.call(terrain_vertices[-1].x, bottom_y, -1.0)
	
# Scale to [0,1] as noise is [-1,1]
func _sample_height_frac(x: float) -> float:
	return (_noise.get_noise_1d(x) + 1) * 0.5

func _generate_noise() -> FastNoiseLite:
	var noise : FastNoiseLite
	
	if noise_template:
		noise = noise_template.duplicate()
	else:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		
	if randomize_seed:
		noise.seed = randi()
	
	print_debug("%s - Using seed=%d for noise" % [name, noise.seed])
	
	return noise
