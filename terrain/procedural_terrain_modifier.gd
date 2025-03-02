class_name ProceduralTerrainModifier extends Node

@export var noise_template : FastNoiseLite
@export var randomize_seed:bool = true

@export_category("Generation")
@export_range(0, 1000) var additional_vertices:int = 0
# TODO: May want to have a parameter for vertex density

@export_category("Generation")
@export var replace_existing_heights:bool = false

@export_category("Generation")
@export_range(-1,1,0.01) var height_win_size_min_variation:float = -0.1
@export_category("Generation")
@export_range(-1,1,0.01) var height_win_size_max_variation:float = 0.1

@export_category("Generation")
@export_range(0,100,0.01) var min_height_value:float = 20

@export_category("Generation")
@export_range(0,1000,0.01) var max_height_clearance:float = 50

@export_category("Generation")
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

	var viewport_bounds := _terrain.get_viewport_rect()
	var current_terrain_bounds := _terrain.get_bounds_global()

	for chunk in _terrain.get_chunks():
		_modify_chunk(chunk, viewport_bounds, current_terrain_bounds)

func _modify_chunk(chunk: TerrainChunk, viewport_bounds: Rect2, _terrain_bounds: Rect2) -> void:

	var min_height := max_height_clearance
	var max_height := viewport_bounds.size.y - min_height_value
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
	
	# First modify any existing points
	for i in range(terrain_vertices.size()):
		var vertex := terrain_vertices[i]

		# Only modify exterior vertices
		if !chunk.is_surface_point_global(vertex):
			continue
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

	# Now add additional vertices requested
	var new_terrain_vertices:PackedVector2Array
	if additional_vertices > 0:
		var new_terrain:bool
		
		if terrain_vertices.is_empty():
			new_terrain = true
			_seed_terrain(terrain_vertices, viewport_bounds, 4)
			# HACK:
			chunk.replace_contents(terrain_vertices, [], true)
		else:
			new_terrain = false
			
		var total_vertices:int = terrain_vertices.size() + additional_vertices
		var ideal_spacing:float = viewport_bounds.size.x / total_vertices
				
		var vertices_remaining := additional_vertices
		var prev_point:Vector2 = Vector2(viewport_bounds.position.x, min_height)
		var next_point:Vector2 = Vector2(viewport_bounds.size.x, max_height)
				
		new_terrain_vertices = []
		
		for i in range(0, terrain_vertices.size()):
			if i == terrain_vertices.size() - 1 or !chunk.is_surface_point_global(terrain_vertices[i]):
				new_terrain_vertices.push_back(terrain_vertices[i])
				continue
						
			prev_point = terrain_vertices[i]
			next_point = terrain_vertices[i+1]
				
			var total_to_add:int = 	mini(
				next_point.distance_to(prev_point) / ideal_spacing, vertices_remaining)
			
			if total_to_add == 0:
				continue
				
			var last_point:Vector2 = prev_point
			new_terrain_vertices.push_back(prev_point)
						
			var direction:int = sign(next_point.x - last_point.x)
			var ideal_height_inc: float = (next_point.y - last_point.y) / total_to_add
			var min_x = minf(last_point.x, next_point.x)
			var max_x = maxf(last_point.x, next_point.x)
			
			var added_count:int = 0
			for j in range(total_to_add):
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
			if vertices_remaining <= 0:
				break
		# end for all terrain_vertices
	else:
		new_terrain_vertices = terrain_vertices
	
	# Update final terrain
	chunk.replace_contents(new_terrain_vertices)

func _seed_terrain(terrain_vertices : PackedVector2Array, viewport_bounds: Rect2, count: int) -> void:
	var bottom_y:float = viewport_bounds.size.y
	var top_y:float = (bottom_y - min_height_value + max_height_clearance) * 0.5
	
	# Need 2 for the bottom
	var top_count : int = count - 2
	var stride: float = viewport_bounds.size.x / (top_count - 1)
	
	var x:float = viewport_bounds.position.x
	for i in range(top_count):
		terrain_vertices.push_back(Vector2(x, top_y))
		x += stride
		
	terrain_vertices.push_back(Vector2(terrain_vertices[top_count - 1].x, bottom_y))
	terrain_vertices.push_back(Vector2(viewport_bounds.position.x, bottom_y))
	
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
	
	return noise
