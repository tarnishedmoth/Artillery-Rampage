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
	# Array.filter is broken!  See https://github.com/godotengine/godot/issues/72566
	var opponents: Array[TankController] = []
	for controller in game_level.round_director.tank_controllers:
		if controller != tank.owner:
			opponents.push_back(controller)
	return opponents
		
func has_line_of_sight_to(start_pos: Vector2, end_pos: Vector2) -> Dictionary:
	var space_state := tank.get_world_2d().direct_space_state

	var query_params := PhysicsRayQueryParameters2D.create(
		start_pos, end_pos,
		Collisions.CompositeMasks.obstacle)

	var result: Dictionary = space_state.intersect_ray(query_params)

	if !result:
		print_debug("%s: start_pos=%s; end_pos=%s -> TRUE" % [tank.owner.name, str(start_pos), str(end_pos)])
		return { test = true }
	
	print_debug("%s: start_pos=%s; end_pos=%s -> FALSE - hit=%s -> %s" 
		% [tank.owner.name, str(start_pos), str(end_pos), result.collider.name, str(result.position)])

	return { test = false, position = result.position }

func get_direct_aim_angle_to(opponent: TankController, forces: int = 0) -> float:
	var turret_position: Vector2 = tank.turret.global_position
	# Needs to be relative to turret neutral position which is up
	var up_vector: Vector2 = Vector2.UP.rotated(tank.tankBody.global_rotation)

	# By default aim to the center of the opponent
	var opponent_position: Vector2 = opponent.tank.tankBody.global_position

	var to_opponent: Vector2 = opponent_position - turret_position
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, forces)
	var aim_pos: Vector2 = opponent_position + pos_offset
	
	var to_opponent_dir = turret_position.direction_to(aim_pos)
	var angle := up_vector.angle_to(to_opponent)

	return clampf(rad_to_deg(angle), tank.min_angle, tank.max_angle)

func has_direct_shot_to(opponent : TankController, forces: int = 0) -> Dictionary:
	# Test from barrel to test points on artillery
	var turret_position: Vector2 = tank.turret.global_position
	var opponent_position:Vector2 = opponent.tank.tankBody.global_position

	var up_vector: Vector2 = Vector2.UP.rotated(tank.tankBody.global_rotation)
	
	var opponent_tank: Tank = opponent.tank
	var test_positions: PackedVector2Array = opponent_tank.get_body_reference_points_global()

	var to_opponent: Vector2 = opponent_position - turret_position
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, forces)

	print_debug("%s: LOS opponent=%s; calculated pos_offset=%s -> %f"  % [tank.owner.name, opponent.name, pos_offset, pos_offset.length()])

	for i in range(test_positions.size()):
		test_positions[i] += pos_offset
	
	# First check that we can even aim directly at the opponent and limit to those viable positions
	var viable_positions: PackedVector2Array = []
	var viable_angles : PackedFloat32Array = []

	for position in test_positions:
		var to_pos := turret_position.direction_to(position)
		var angle := rad_to_deg(up_vector.angle_to(to_pos))
		
		print_debug("%s: LOS opponent=%s; pos=%s; angle=%f"  % [tank.owner.name, opponent.name, position, angle])

		if angle >= tank.min_angle and angle <= tank.max_angle:
			viable_positions.append(position)
			viable_angles.append(angle)
				
	var fire_position: Vector2 = tank.get_weapon_fire_locations().global_position

	var has_los:bool = false
	var max_position:Vector2 = fire_position
	var max_distance:float = 0.0
	var aim_position:Vector2 = Vector2.ZERO
	var aim_angle:float = 0.0
	
	for i in range(viable_positions.size()):
		var position: Vector2 = viable_positions[i]
		var result : Dictionary = has_line_of_sight_to(fire_position, position)
		if result.test:
			has_los = true
			aim_position = position
			aim_angle = viable_angles[i]
			break
		else:
			var dist := fire_position.distance_squared_to(result.position)
			if dist > max_distance:
				max_distance = dist
				max_position = result.position
	
	if has_los:
		print_debug("%s: LOS to opponent=%s -> TRUE; tested_positions=%d"
		 % [tank.owner.name, opponent.name, str(has_los), str(viable_positions.size())])
		return { test = true, position = aim_position, aim_angle = aim_angle }
		
	print_debug("%s: LOS to opponent=%s -> FALSE -> %s; tested_positions=%d" 
		% [tank.owner.name, opponent.name, str(max_position), viable_positions.size()])
	
	return { test = false, position = max_position }

#region Forces
class Forces:
	const Gravity:int = 1
	const Wind:int = 1 << 1
	
	const All: int = Gravity | Wind
	
func _get_active_forces_offset(aim_trajectory: Vector2, forces: int) -> Vector2:
	var total_offset: Vector2 = Vector2.ZERO
	
	if forces & Forces.Gravity:
		total_offset += _get_gravity_offset(aim_trajectory)
	if forces & Forces.Wind:
		total_offset += _get_wind_offset(aim_trajectory)
	
	return total_offset
	
func _get_gravity_offset(aim_trajectory: Vector2) -> Vector2:
	# TODO: Determine how best to read this - maybe its a setting passed down from the game level?
	# Power value chosen will also influence the gravity effect
	# Gravity acceleration is based on project settings DefaultGravity multiplied by GravityScale from WeaponProjectile clsas
	# Need fire_velocity from weapon to be able to calculate the offset
	# Right now just apply a multiplier based on the delta y
	# We need to consider the projectile motion physics and the kinematic equations
	return Vector2(0.0, aim_trajectory.y * absf(aim_trajectory.x) * 0.002 )

func _get_wind_offset(aim_trajectory: Vector2) -> Vector2:
	# TODO: Compensate for Wind which is always horizontal
	return Vector2()
	
#endregion
	
