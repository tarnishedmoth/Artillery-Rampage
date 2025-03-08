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

func get_direct_aim_angle_to(opponent: TankController, launch_speed: float, forces: int = 0) -> float:
	var turret_position: Vector2 = tank.turret.global_position
	# By default aim to the center of the opponent
	var opponent_position: Vector2 = opponent.tank.tankBody.global_position

	var to_opponent: Vector2 = opponent_position - turret_position
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, launch_speed, forces)
	
	var aim_pos: Vector2 = opponent_position + pos_offset

	return _get_direct_aim_angle_to(turret_position, launch_speed, aim_pos)

func _get_direct_aim_angle_to(from_pos: Vector2, launch_speed: float, to_pos: Vector2) -> float:
	# Needs to be relative to turret neutral position which is up
	var up_vector: Vector2 = Vector2.UP.rotated(tank.tankBody.global_rotation)
	
	var dir := from_pos.direction_to(to_pos)
	var angle := up_vector.angle_to(dir)

	return clampf(rad_to_deg(angle), tank.min_angle, tank.max_angle)
	
func has_direct_shot_to(opponent : TankController, launch_speed: float, forces: int = 0) -> Dictionary:
	# Test from barrel to test points on artillery
	var turret_position: Vector2 = tank.turret.global_position
	var opponent_position:Vector2 = opponent.tank.tankBody.global_position

	var up_vector: Vector2 = Vector2.UP.rotated(tank.tankBody.global_rotation)
	
	var opponent_tank: Tank = opponent.tank
	var test_positions: PackedVector2Array = opponent_tank.get_body_reference_points_global()

	var to_opponent: Vector2 = opponent_position - turret_position
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, launch_speed, forces)

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
	
func _get_active_forces_offset(aim_trajectory: Vector2, launch_speed: float, forces: int) -> Vector2:
	var total_offset: Vector2 = Vector2.ZERO
	
	if forces & Forces.Gravity:
		total_offset += _get_gravity_offset(aim_trajectory, launch_speed)
	if forces & Forces.Wind:
		total_offset += _get_wind_offset(aim_trajectory, launch_speed)
	
	return total_offset
	
func _get_gravity_offset(aim_trajectory: Vector2, launch_speed: float) -> Vector2:
	if is_zero_approx(launch_speed):
		return Vector2.ZERO
		
	# TODO: Determine how best to read this - maybe its a setting passed down from the game level?
	# Power value chosen will also influence the gravity effect
	# Gravity acceleration is based on project settings DefaultGravity multiplied by GravityScale from WeaponProjectile clsas
	# Need fire_velocity from weapon to be able to calculate the offset
	# Right now just apply a multiplier based on the delta y
	# We need to consider the projectile motion physics and the kinematic equations
	# TODO: This may be affected by the wind though we are calculating that contribution separately
	
	var launch_angle: float = absf(aim_trajectory.angle())
	var vx: float = launch_speed * cos(launch_angle)
	if is_zero_approx(vx):
		return Vector2.ZERO
		
	var vy: float = launch_speed * sin(launch_angle)
	# Calculate time from horizontal component
	# x = v*cos(a)  * t
	var flight_time: float =  aim_trajectory.x / vx
	
	# dy = 1/2 * a * t^2 + voy * t
	var delta_y : float = 0.5 * PhysicsUtils.get_gravity_vector().y * flight_time * flight_time + vy * flight_time
	
	# Negate aim_trajectory_y since y coords inverted meaning bigger y is down
	var additional_y: float = -delta_y - aim_trajectory.y
	return Vector2(0.0, additional_y)

func _get_wind_offset(aim_trajectory: Vector2, launch_speed: float) -> Vector2:
	# TODO: Compensate for Wind which is always horizontal
	# For this one we will use F = m * a but need the mass of the projectile and then can use x 
	return Vector2()
	
#endregion
	
