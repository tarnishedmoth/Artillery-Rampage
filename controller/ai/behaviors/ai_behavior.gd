class_name AIBehavior extends Node

class LaunchProperties:
	var speed: float
	var mass: float = 1.0

class WeaponInfo:
	var weapon: Weapon
	var projectile_prototype: WeaponProjectile
	
	func delete() -> void:
		if projectile_prototype:
			projectile_prototype.queue_free()
			projectile_prototype = null

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
	var result: Dictionary = check_world_collision(start_pos, end_pos)

	if !result:
		print_debug("%s: start_pos=%s; end_pos=%s -> TRUE" % [tank.owner.name, str(start_pos), str(end_pos)])
		return { test = true }
	
	print_debug("%s: start_pos=%s; end_pos=%s -> FALSE - hit=%s -> %s" 
		% [tank.owner.name, str(start_pos), str(end_pos), result.collider.name, str(result.position)])

	return { test = false, position = result.position }

func check_world_collision(start_pos: Vector2, end_pos: Vector2) -> Dictionary:
	var space_state := tank.get_world_2d().direct_space_state

	var query_params := PhysicsRayQueryParameters2D.create(
		start_pos, end_pos,
		Collisions.CompositeMasks.obstacle)

	var result: Dictionary = space_state.intersect_ray(query_params)

	return result
func get_direct_aim_angle_to(opponent: TankController, launch_props: LaunchProperties, forces: int = 0) -> float:
	var turret_position: Vector2 = tank.turret.global_position
	# By default aim to the center of the opponent
	var opponent_position: Vector2 = opponent.tank.tankBody.global_position

	var to_opponent: Vector2 = opponent_position - turret_position
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, launch_props, forces)
	
	var aim_pos: Vector2 = opponent_position + pos_offset

	return _get_direct_aim_angle_to(turret_position, aim_pos)

func _get_direct_aim_angle_to(from_pos: Vector2, to_pos: Vector2) -> float:
	# Needs to be relative to turret neutral position which is up
	var up_vector: Vector2 = Vector2.UP.rotated(tank.tankBody.global_rotation)
	
	var dir := from_pos.direction_to(to_pos)
	var angle := up_vector.angle_to(dir)

	return clampf(rad_to_deg(angle), tank.min_angle, tank.max_angle)
	
func aim_angle_to_world_direction(angle: float) -> Vector2:
	var turret_angle: float = tank.turret.global_rotation
	var world_angle: float = turret_angle + rad_to_deg(angle)
	
	return Vector2.UP.rotated(rad_to_deg(world_angle))

func has_direct_shot_to(opponent : TankController, launch_props: LaunchProperties, forces: int = 0) -> Dictionary:
	# Test from barrel to test points on artillery
	var turret_position: Vector2 = tank.turret.global_position
	var opponent_position:Vector2 = opponent.tank.tankBody.global_position

	var up_vector: Vector2 = Vector2.UP.rotated(tank.tankBody.global_rotation)
	
	var opponent_tank: Tank = opponent.tank
	var test_positions: PackedVector2Array = opponent_tank.get_body_reference_points_global()

	var to_opponent: Vector2 = opponent_position - turret_position
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, launch_props, forces)

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
		 % [tank.owner.name, opponent.name, viable_positions.size()])
		return { test = true, position = aim_position, aim_angle = aim_angle }
		
	print_debug("%s: LOS to opponent=%s -> FALSE -> %s; tested_positions=%d" 
		% [tank.owner.name, opponent.name, str(max_position), viable_positions.size()])
	
	return { test = false, position = max_position }

#region Forces
class Forces:
	const Gravity:int = 1
	const Wind:int = 1 << 1
	
	const All: int = Gravity | Wind
	
func _get_active_forces_offset(aim_trajectory: Vector2, launch_props: LaunchProperties, forces: int) -> Vector2:
	var total_offset: Vector2 = Vector2.ZERO
	
	if forces & Forces.Gravity:
		total_offset += _get_gravity_offset(aim_trajectory, launch_props)
	if forces & Forces.Wind:
		total_offset += _get_wind_offset(aim_trajectory, launch_props)
	
	return total_offset
	
func _get_gravity_offset(aim_trajectory: Vector2, launch_props: LaunchProperties) -> Vector2:
	return _get_force_accel_offset(aim_trajectory, launch_props.speed, PhysicsUtils.get_gravity_vector())

func _get_wind_offset(aim_trajectory: Vector2, launch_props: LaunchProperties) -> Vector2:
	if is_zero_approx(launch_props.speed) or is_zero_approx(launch_props.mass):
		return Vector2.ZERO
	
	var wind_force: Vector2 = _get_wind_force()
	if wind_force.is_zero_approx():
		return Vector2.ZERO
		
	# F = m * a
	var wind_accel : Vector2 = wind_force / launch_props.mass / 100
	# Negate to compensate for the wind
	return _get_force_accel_offset(aim_trajectory, launch_props.speed, -wind_accel)
	
func _get_force_accel_offset(aim_trajectory: Vector2, launch_speed: float, acceleration: Vector2) -> Vector2:
	if is_zero_approx(launch_speed):
		return Vector2.ZERO

	var aim_trajectory_dir: Vector2 = aim_trajectory.normalized()

	var launch_velocity: Vector2 = aim_trajectory_dir * launch_speed
	if is_zero_approx(launch_velocity.x):
		return Vector2.ZERO
		
	# Calculate time from horizontal component
	# x = vx  * t
	var flight_time: float =  aim_trajectory.x / launch_velocity.x
	
	# d = 1/2 * a * t^2 + voy * t
	var final_pos : Vector2 = 0.5 * acceleration * flight_time * flight_time + launch_velocity * flight_time
	
	# Determine how much additional pos we need to hit the final pos of the flight
	var additional_pos: Vector2 = aim_trajectory - final_pos
	return additional_pos
	
func _get_wind_force() -> Vector2:
	var wind: Wind = game_level.wind
	return wind.force if wind else Vector2.ZERO
#endregion
	
#region Weapons
func get_weapon_infos() -> Array[WeaponInfo]:
	var weapon_infos: Array[WeaponInfo] = []
	
	for weapon in tank.weapons:
		var weapon_info: WeaponInfo = WeaponInfo.new()
		weapon_info.weapon = weapon
		
		var scene_to_spawn: PackedScene = weapon.scene_to_spawn
		if scene_to_spawn and scene_to_spawn.can_instantiate():
			weapon_info.projectile_prototype = scene_to_spawn.instantiate() as WeaponProjectile
			
		weapon_infos.push_back(weapon_info)
		
	return weapon_infos
	
func delete_weapon_infos(weapon_infos: Array[WeaponInfo]) -> void:
	for info in weapon_infos:
		info.delete()
	weapon_infos.clear()
#endregion
