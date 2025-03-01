class_name ProceduralTerrainModifier extends Node

@export var noise_template : FastNoiseLite
@export var randomize_seed:bool = true


@export_category("Generation")
@export_range(0, 1000) var additional_vertices:int = 0
# TODO: May want to have a parameter for vertex density
var replace_existing_heights:bool = false

@export_category("Generation")
@export_range(-1,1,0.01) var height_win_size_min_variation:float = -0.1
@export_category("Generation")
@export_range(-1,1,0.01) var height_win_size_max_variation:float = 0.1

@export_category("Generation")
@export_range(0,100,0.01) var min_height:float = 20

@export_category("Generation")
@export_range(0,1000,0.01) var max_height_clearance:float = 50

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

	var max_height := viewport_bounds.size.y - max_height_clearance
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
	
	for i in range(terrain_vertices.size()):

		var vertex := terrain_vertices[i]

		if !chunk.is_surface_point_global(vertex):
			continue
		# Only modify exterior vertices
		# Scale to [0,1] as noise is [-1,1]
		var raw_height_fract := (_noise.get_noise_1d(vertex.x) + 1) * 0.5

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

	chunk.replace_contents(terrain_vertices)
	
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
