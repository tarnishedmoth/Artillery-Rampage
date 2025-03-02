class_name ArtillerySpawner extends Node

@export var artillery_ai_types: Array[PackedScene] = []
@export var default_ai_players: Vector2i = Vector2i()
@export var default_human_players: Vector2i = Vector2i()

@export_range(-100, 100) var spawn_y_offset: float = -10.0
@export_range(20, 250) var ideal_min_spawn_separation: float = 100.0

@export_range(0, 1e9, 1, "or_greater")
var min_boundary_x_distance: float = 40

const player_type : PackedScene = preload("res://controller/player/player.tscn")

# Need to wait for the terrain to finish building before doing raycasts
const spawn_delay:float = 0.2

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
	
	if !await _calculate_spawn_positions(terrain, total_spawns):
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
	# Disable fall damage - important especially for the procedural spawning as right now we generate points on a slant
	controller.enable_damage_before_first_turn = false
	if controller is AITank:
		controller.set_color(Color(randf(), randf(), randf()))
		
func _calculate_spawn_positions(terrain: Terrain, count: int) -> bool:
	var success:bool = true
	for marker in _specified_positions:
		_all_positions.push_back(marker.global_position)
	
	await _generate_spawns(terrain, count - _all_positions.size())
	
	if count > _all_positions.size():
		push_warning("ArtillerySpawner(%s): Requesting %d spawns but only %d available" % [name, count, _all_positions.size()])
		success = false
		count = _all_positions.size()
	
	# Sort positions by x
	_all_positions.sort_custom(func(a:Vector2, b:Vector2) -> bool: return a.x < b.x)	
	_choose_positions(count)
			
	return success
	
func _generate_spawns(terrain: Terrain, requested_count: int) -> void:
	if requested_count <= 0:
		return
	
	await get_tree().create_timer(spawn_delay).timeout

	var spawn_bounds := terrain.get_bounds_global()
	
	# Subtract out the safe bounds on either side
	var spawnable_size: float = spawn_bounds.size.x - (min_boundary_x_distance * 2)
	var stride:float = spawnable_size / requested_count
	var min_x:float = spawn_bounds.position.x + min_boundary_x_distance
	var min_spawn_separation:float = min(ideal_min_spawn_separation, stride)
	
	var last_x:float = min_x
	
	for i in range(0, requested_count):
		var x:float = max(min_x + randf_range(i * stride, (i + 1) * stride),
			last_x + min_spawn_separation)
		
		var pos := _get_spawn_position(terrain, x)
		last_x = pos.x
		
		_all_positions.push_back(pos)

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
		
func _get_spawn_position(terrain: Terrain, x: float) -> Vector2:
	var from:Vector2 = Vector2(x, 0)
	var to:Vector2 = Vector2(x, get_viewport().size.y)
	
	var query_params = PhysicsRayQueryParameters2D.create(from, to,
	 Collisions.CompositeMasks.tank_snap)
	
	var space_state := terrain.get_world_2d().direct_space_state
	var result = space_state.intersect_ray(query_params)

	if !result:
		push_error("ArtillerySpawner(%s): _get_spawn_position could not find y - x=%f" % [name, x])
		return from
		
	return result["position"] + Vector2(0, spawn_y_offset)
