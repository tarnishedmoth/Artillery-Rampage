class_name ArtillerySpawner extends Node

@export var artillery_ai_types: Array[PackedScene] = []
@export var default_ai_players: Vector2i = Vector2i()
@export var default_human_players: Vector2i = Vector2i()

const player_type : PackedScene = preload("res://controller/player/player.tscn")

var _specified_positions: Array[Marker2D] = []
var _all_positions: Array[Vector2] = []
var _used_positions: Array[Vector2] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_populate_specified_positions()

# Vector2i has [min,max] for each type
func spawn_all(terrain: Terrain, ai_players: Vector2i = Vector2i(), human_players: Vector2i = Vector2i()) -> Array[TankController]:
	_used_positions.clear()
	_all_positions.clear()
	
	if ai_players.x <= 0:
		ai_players = default_ai_players
	if human_players.x <= 0:
		human_players = default_human_players
	
	var num_ai := randi_range(ai_players.x, ai_players.y)
	var num_human := randi_range(human_players.x, human_players.y)
	var total_spawns := num_ai + num_human
	
	if total_spawns <= 0:
		print("ArtillerySpawner(%s): No spawning requested - returning []" % [name])
		return []
	
	print("ArtillerySpawner(%s): Requesting spawning - num_ai=%d; num_human=%d" % [name, num_ai, num_human])
	
	if !_calculate_spawn_positions(terrain, total_spawns):
		push_warning("ArtillerySpawner(%s): Unable to generate requested spawn count=%d; generated=%d" % [name, total_spawns, _used_positions.size()])
		
	var spawned_list := _spawn_units(num_ai, num_human)
	
	return spawned_list

func _populate_specified_positions() -> void:
	for child in get_children():
		if child is Marker2D:
			_specified_positions.push_back(child)

func _instantiate_controller_scene_at(scene: PackedScene, position: Vector2) -> TankController:
	if !scene:
		push_error("ArtillerySpawner(%s): Unable to create TankController from NULL scene" % [name])
	var instance := scene.instantiate() as TankController
	if !instance:
		push_error("ArtillerySpawner(%s): Unable to create TankController from packed scene=%s" % [name, scene])
	instance.global_position = position
	return instance

func _calculate_spawn_positions(terrain: Terrain, count: int) -> bool:
	var success:bool = true
	# TODO: Implement spreading out and adding additional random positions based on terrain
	for marker in _specified_positions:
		_all_positions.push_back(marker.global_position)
	
	if count > _all_positions.size():
		push_warning("ArtillerySpawner(%s): Requesting %d spawns but only %d available" % [name, count, _all_positions.size()])
		success = false
		count = _all_positions.size()
		
	_all_positions.shuffle()
	_used_positions = _all_positions.slice(0, count)
		
	return success

func _spawn_units(num_ai: int, num_human: int) -> Array[TankController]:
	var all_spawned : Array[TankController] = []
	
	for i in range(0, _used_positions.size()):
		var scene:PackedScene
		if i < num_human:
			scene = player_type
		else:
			scene = artillery_ai_types.pick_random()
		var spawned := _instantiate_controller_scene_at(scene, _used_positions[i])
		if spawned:
			add_child(spawned)
			all_spawned.push_back(spawned)
	
	return all_spawned
	
