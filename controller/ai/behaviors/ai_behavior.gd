class_name AIBehavior extends Node

var tank: Tank

func _ready() -> void:
	pass

var game_level: GameLevel:
	get: return SceneManager.get_current_level_root()
	
func execute(tank: Tank) -> AIState:
	self.tank = tank
	return null

func get_opponents() -> Array[TankController]:
	return game_level.round_director.tank_controllers.filter(func(c : TankController): return c != tank.owner)
	
func has_line_of_sight_to(start_pos: Vector2, end_pos: Vector2) -> Dictionary:
	var space_state := tank.get_world_2d().direct_space_state

	var query_params := PhysicsRayQueryParameters2D.create(
		start_pos, end_pos,
		Collisions.CompositeMasks.visibility)

	var result: Dictionary = space_state.intersect_ray(query_params)

	if !result:
		print_debug("%s: start_pos=%s; end_pos=%s -> TRUE" % [tank.owner.name, str(start_pos), str(end_pos)])
		return { test = true }
	
	print_debug("%s: start_pos=%s; end_pos=%s -> FALSE - hit=%s -> %s" 
		% [tank.owner.name, str(start_pos), str(end_pos), result.collider.name, str(result.position)])

	return { test = false, position = result.position }

func has_direct_shot_to(opponent : TankController) -> Dictionary:
	# Test from barrel to test points on artillery
	# TODO: Need to pre-filter by angle restriction as this is assuming we can aim 360 degrees
	# Ideally the rotation range of the tank should be a function on the tank itself and don't bake in any assumptions here
	var fire_position: Vector2 = tank.get_weapon_fire_locations().global_position
	
	var opponent_tank: Tank = opponent.tank
	var test_positions: PackedVector2Array = opponent_tank.get_body_reference_points_global()
	
	var has_los:bool = false
	var max_position:Vector2 = fire_position
	var max_distance:float = 0.0
	
	for position in test_positions:
		var result : Dictionary = has_line_of_sight_to(fire_position, position)
		if result.test:
			has_los = true
			break
		else:
			var dist := fire_position.distance_squared_to(result.position)
			if dist > max_distance:
				max_distance = dist
	
	if has_los:
		print_debug("%s: LOS to opponent=%s -> TRUE" % [tank.owner.name, opponent.name, str(has_los)])
		return { test = true }
		
	print_debug("%s: LOS to opponent=%s -> FALSE -> %s" % [tank.owner.name, opponent.name, str(max_position)])
	
	return { test = false, position = max_position }
