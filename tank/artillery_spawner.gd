class_name ArtillerySpawner extends Node

@export var artillery_ai_types: Array[PackedScene] = []
@export var default_ai_players: Vector2i = Vector2i()
@export var default_human_players: Vector2i = Vector2i()

@export_range(0, 100) var terrain_y_offset: float = 20.0

const player_type : PackedScene = preload("res://controller/player/player.tscn")

var _specified_positions: Array[Marker2D] = []
var _all_positions: Array[Vector2] = []
var _used_positions: Array[Vector2] = []

var enemy_names: Array[String] = [
	"Billy", "Rob", "Don", "Jerry", "Peter", "Amanda", "Alex", "Alexa", 
	"Betty", "Suzy", "Ann", "Andy", "Mike", "Becky", "Molly", "Erica", "Eric",
	"Harry", "Ian", "Fred", "Phil", "Cindy", "Daisy", "Tanky", "Arty"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enemy_names.shuffle()
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
	
	print("ArtillerySpawner(%s): Requesting spawning - num_ai=%d [%d-%d]; num_human=%d [%d-%d]" 
	% [name, num_ai, ai_players.x, ai_players.y, num_human, human_players.x, human_players.y])
	
	if !_calculate_spawn_positions(terrain, total_spawns):
		push_warning("ArtillerySpawner(%s): Unable to generate requested spawn count=%d; generated=%d" % [name, total_spawns, _used_positions.size()])
		
	var spawned_list := _spawn_units(num_human)
	
	return spawned_list

func _populate_specified_positions() -> void:
	for child in get_children():
		if child is Marker2D:
			_specified_positions.push_back(child)

func _instantiate_controller_scene_at(scene: PackedScene, position: Vector2) -> TankController:
	if !scene:
		push_error("ArtillerySpawner(%s): Unable to create TankController from NULL scene" % [name])
		return null
	var instance := scene.instantiate() as TankController
	if instance:
		instance.global_position = position
	else:
		push_error("ArtillerySpawner(%s): Unable to create TankController from packed scene=%s" % [name, scene])
	
	return instance

func init_controller_props(controller: TankController) -> void:
	if controller is AITank:
		controller.set_color(Color(randf(), randf(), randf()))
		
func _calculate_spawn_positions(terrain: Terrain, count: int) -> bool:
	var success:bool = true
	# TODO: Implement spreading out and adding additional random positions based on terrain
	for marker in _specified_positions:
		_all_positions.push_back(marker.global_position)
	
	if count > _all_positions.size():
		push_warning("ArtillerySpawner(%s): Requesting %d spawns but only %d available" % [name, count, _all_positions.size()])
		success = false
		count = _all_positions.size()
	
	# Sort positions by x
	_all_positions.sort_custom(func(a:Vector2, b:Vector2) -> bool: return a.x < b.x)	
	_choose_positions(count)
			
	return success

func _choose_positions(count: int) -> void:
	if count < _all_positions.size():
		# Assuming the points are evenly distributed
		var max_position:int = _all_positions.size() - 1
		var stride:float = float(_all_positions.size()) / count
		
		var _used_indices:Array[int] = []
		
		for i in range(0, count):
			var index:int = mini(roundi(randf_range(i * stride, (i + 1) * stride)), max_position)
			# Already guarded against infinite loop as clamp count to max positions
			# This shouldn't happen much - only in cases of player count to 
			while index in _used_indices:
				index -= 1
				if index < 0:
					index = max_position
			_used_indices.push_back(index)
			_used_positions.push_back(_all_positions[index])
	else: 	# Special case of total positions available is count
		_used_positions.append_array(_all_positions)
	
	# Shuffle final positions since the AI to player ratio is based on the index
	_used_positions.shuffle()
	
func _spawn_units(num_human: int) -> Array[TankController]:
	var all_spawned : Array[TankController] = []
	
	var ai_count:int = 0
	
	for i in range(0, _used_positions.size()):
		var scene:PackedScene
		var is_ai:bool = false
		
		if i < num_human:
			scene = player_type
		else:
			is_ai = true
			ai_count += 1
			scene = artillery_ai_types.pick_random()
		var spawned := _instantiate_controller_scene_at(scene, _used_positions[i])
		if spawned:
			# Give AI random names
			if is_ai:
				spawned.name = enemy_names[ (ai_count - 1) % enemy_names.size()]
			add_child(spawned)
			# Child nodes are null until added to the scene
			init_controller_props(spawned)
			
			all_spawned.push_back(spawned)
	
	return all_spawned
		
