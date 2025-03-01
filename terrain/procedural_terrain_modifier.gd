class_name ProceduralTerrainModifier extends Node

@export var noise_template : FastNoiseLite
@export var randomize_seed:bool = true

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
	pass
	
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
