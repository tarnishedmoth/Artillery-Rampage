class_name AIBehavior extends Node

var behavior_type: Enums.AIBehaviorType

## Set default priority returned when no other conditions match for state selection
@export var default_priority:int = 1

var track_shot_history:bool = false

class LaunchProperties:
	var speed: float
	var power_speed_mult: float = 1.0
	var mass: float = 1.0

class WeaponInfo:
	var weapon: Weapon
	var projectile_prototype: WeaponProjectile
	
	func delete() -> void:
		if projectile_prototype:
			projectile_prototype.queue_free()
			projectile_prototype = null

class OpponentTargetHistory:
	var opponent: TankController
	var my_position: Vector2
	var opp_position: Vector2
	var hit_location: Vector2 = Vector2.ZERO
	var fire_time: float
	var hit_time: float
	var hit_count: int # For multi-shot
	var power: float
	var max_power: float
	var angle: float

var tank: Tank

var has_player_fired: bool = false

# Dictionary of opponent to Array[OpponentTargetHistory]
var _opponent_target_history: Dictionary = {}
var last_opponent_history_entry: OpponentTargetHistory


func _ready() -> void:
	# Listen to track opponent targeting feedback and if player has fired
	GameEvents.projectile_fired.connect(_on_projectile_fired)

var game_level: GameLevel:
	get: return SceneManager.get_current_level_root()
	

var aim_fulcrum_position: Vector2:
	get: return  tank.turret.global_position
	
func execute(tank_unit: Tank) -> AIState:
	self.tank = tank_unit
	return null

func get_opponents() -> Array[TankController]:
	# Array.filter is broken!  See https://github.com/godotengine/godot/issues/72566
	var opponents: Array[TankController] = []
	for controller in game_level.round_director.tank_controllers:
		if controller != tank.owner:
			opponents.push_back(controller)
	return opponents
	
#region Aim and LOS	

func get_power_for_target_and_angle(target: Vector2, angle: float, launch_props: LaunchProperties, forces: int = 0) -> float:
	# See https://en.wikipedia.org/wiki/Range_of_a_projectile
	var source: Vector2 = aim_fulcrum_position

	# If adjusting for walls then get the adjusted target
	var adjusted_target: Vector2 = get_target_end_walls(source, target, forces)

	# Adjusting target for max power if wind should be taken into account
	if forces & Forces.Wind:
		var orig_launch_speed := launch_props.speed
		launch_props.speed = tank.max_power * launch_props.power_speed_mult
		adjusted_target += _get_wind_offset(adjusted_target - source, launch_props)
		launch_props.speed = orig_launch_speed

	# Wolfram Alpha: Solve d = v * cos(theta) / g * (v * sin(theta) + sqrt(v ^ 2 * sin(theta)^2 + 2 * g * y)) for v
	# v = d * sqrt(g) / (sqrt(2 * d * sin(theta) + 2 * y * cos(theta)) * sqrt(cos(theta))

	# Y should be positive for targets below, since y increases going down this works out
	var y: float = adjusted_target.y - source.y
	var x: float = absf(adjusted_target.x - source.x)

	var g : float = PhysicsUtils.get_gravity_vector().y

	var sin_angle: float = sin(deg_to_rad(angle))
	var cos_angle: float = cos(deg_to_rad(angle))

	var sqrt_term: float = 2 * x * sin_angle + 2 * y * cos_angle
	if sqrt_term <= 0:
		print_debug("%s: Unreachable target=%s; angle=%f" % [tank.owner.name, target, angle])
		return -1

	var speed: float = x * sqrt(g) / (sqrt(sqrt_term) * sqrt(cos_angle))

	# If speed is greater than max power then angle is not viable
	var target_power = speed / launch_props.power_speed_mult

	print_debug("%s: target=%s; angle=%f; required power=%f - %s" % [tank.owner.name, target, angle, target_power, str(target_power <= tank.max_power)])

	if target_power > tank.max_power:
		return -1

	return target_power

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
	var aim_source_pos: Vector2 = aim_fulcrum_position

	# By default aim to the center of the opponent
	var opponent_position: Vector2 = get_target_end_walls(aim_source_pos, opponent.tank.tankBody.global_position, forces)

	var to_opponent: Vector2 = opponent_position - aim_source_pos
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, launch_props, forces)
	
	var aim_target_pos: Vector2 = opponent_position + pos_offset

	return _get_direct_aim_angle_to(aim_source_pos, aim_target_pos)

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

func global_angle_to_turret_angle(global_angle: float) -> float:
	return 90 - global_angle
func turret_angle_to_global_angle(turret_angle: float) -> float:
	return 90 - turret_angle

func has_direct_shot_to(opponent : TankController, launch_props: LaunchProperties, forces: int = 0) -> Dictionary:
	# Test from barrel to test points on artillery
	var aim_source_position: Vector2 = aim_fulcrum_position
	var opponent_position:Vector2 = get_target_end_walls(aim_source_position, opponent.tank.tankBody.global_position, forces)

	var up_vector: Vector2 = Vector2.UP.rotated(tank.tankBody.global_rotation)
	
	var opponent_tank: Tank = opponent.tank

	# Get local positions so can offset relative to the walls-adjusted opponent_position
	var test_positions: PackedVector2Array = opponent_tank.get_body_reference_points_local()

	var to_opponent: Vector2 = opponent_position - aim_source_position
	var pos_offset : Vector2 = _get_active_forces_offset(to_opponent, launch_props, forces)

	print_debug("%s: LOS opponent=%s; calculated pos_offset=%s -> %f"  % [tank.owner.name, opponent.name, pos_offset, pos_offset.length()])

	for i in range(test_positions.size()):
		test_positions[i] += opponent_position + pos_offset
	
	# First check that we can even aim directly at the opponent and limit to those viable positions
	var viable_positions: PackedVector2Array = []
	var viable_angles : PackedFloat32Array = []

	for position in test_positions:
		var to_pos := aim_source_position.direction_to(position)
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
		var line_of_sight_positions : PackedVector2Array = get_line_of_sight_positions(fire_position, position, forces)

		var result : Dictionary
		# line of sight positions are pairwise (0, 1), (1, 2), (2, 3), etc. starting with fire_position
		var los_passed:bool = true
		var j:int = 0
		while j < line_of_sight_positions.size() - 1:
			result = has_line_of_sight_to(line_of_sight_positions[j], line_of_sight_positions[j + 1])
			if !result.test:
				los_passed = false
				# Need to compute last result for the position
				j = line_of_sight_positions.size() - 2
			j += 1

		if los_passed:
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
		return { test = true, position = aim_position, aim_angle = aim_angle, adjusted_opponent_position = opponent_position }
		
	print_debug("%s: LOS to opponent=%s -> FALSE -> %s; tested_positions=%d" 
		% [tank.owner.name, opponent.name, str(max_position), viable_positions.size()])
	
	return { test = false, position = max_position, adjusted_opponent_position = opponent_position }

#endregion

#region Forces
class Forces:
	const Gravity:int = 1
	const Wind:int = 1 << 1

	const Walls_Warp:int = 1 << 2
	const Walls_Elastic:int = 1 << 3

	const Walls: int = Walls_Warp | Walls_Elastic
	const All: int = Gravity | Wind | Walls_Warp | Walls_Elastic
	
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
	var wind_accel : Vector2 = _get_wind_accel(wind_force, launch_props)

	return _get_force_accel_offset(aim_trajectory, launch_props.speed, wind_accel)
	
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

func _get_wind_accel(wind_force: Vector2, launch_props: LaunchProperties) -> Vector2:
	# F = m * a
	var wind_accel : Vector2 = wind_force / launch_props.mass / 100
	return wind_accel
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

#region Miss tracking

func _target_is_player_and_has_not_fired(target: TankController) -> bool:
	return !has_player_fired and target is Player

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	if projectile.owner_tank and projectile.owner_tank.owner is Player:
		print_debug("%s: Player has fired - %s" % [name, projectile.owner_tank.owner.name])
		has_player_fired = true

	if !track_shot_history or !tank or projectile.owner_tank != tank:
		return
	
	print_debug("AIBehavior(%s): Projectile Fired=%s" % [tank.owner.name, projectile.name])

	if !last_opponent_history_entry:
		print_debug("AIBehavior(%s): Ignoring blind fire shot for projectile=%s" % [tank.owner.name, projectile.name])
		return

	last_opponent_history_entry.fire_time = _get_current_time_seconds()
	# Need to bind the extra projectile argument to connect
	projectile.completed_lifespan.connect(_on_projectile_destroyed.bind([projectile, last_opponent_history_entry]))

# Bind arguments are passed as an array
func _on_projectile_destroyed(args: Array) -> void:
	var projectile: WeaponProjectile = args[0]
	var opponent_history_entry: OpponentTargetHistory = args[1]

	print_debug("Lobber AIBehavior(%s): Projectile Destroyed=%s" % [tank.owner.name, projectile.name])

	opponent_history_entry.hit_count += 1
	opponent_history_entry.hit_location += projectile.global_position
	opponent_history_entry.hit_time += _get_current_time_seconds()

#endregion

#region Walls

func should_wall_compensate(forces: int) -> bool:
	var walls: Walls = game_level.walls
	if !walls:
		return false
	match walls.wall_mode:
		Walls.WallType.WARP:
			return forces & Forces.Walls_Warp != 0
		Walls.WallType.ELASTIC:
			return forces & Forces.Walls_Elastic != 0
	return false

func get_target_end_walls(start_pos: Vector2, end_pos: Vector2, forces: int) -> Vector2:
	return get_shortest_path_walls(start_pos, end_pos).end if should_wall_compensate(forces) else end_pos

func get_shortest_path_walls(start_pos: Vector2, end_pos: Vector2) -> Dictionary:
	# return all points along the path
	# TODO: May break this out into a separate class
	# TODO: May want to pass in velocities too as these are affected by the elastic mode and may need to loop through certain simulations
	# To get the full result
	# for example for warp you may get 4 results - start -> right wall -> left wall -> end
	# for elastic you may get 4 results - start -> right_wall -> bounce -> end
	# for none you may get 2 results - start -> end
	# TODO: We should calculate this just once and store on this AIBehavior

	# For being determine los and collisions, need to return the intermediate test points when there are walls
	var results: Dictionary = {}
	results.use_walls = false

	var walls: Walls = game_level.walls
	if !walls or walls.wall_mode != Walls.WallType.WARP:
		results.end = end_pos
		return results
	
	# Compare distance squared direct to target and distance squared using walls
	var direction: Vector2 = end_pos - start_pos
	var direct_distance: float = absf(direction.x)

	# Determine direction and need to flip if using walls
	# We will assume they aren't there and just extend the x distance
	var dir_sign: float = signf(direction.x)
	var wall_x_positions: PackedFloat32Array = []

	if dir_sign > 0: # Aiming to right want to check left
		wall_x_positions.push_back(walls.min_extent.x)
		wall_x_positions.push_back(walls.max_extent.x)
	else: # Aiming to left
		wall_x_positions.push_back(walls.max_extent.x)
		wall_x_positions.push_back(walls.min_extent.x)

	var adjusted_end_pos: float = (wall_x_positions[0] - start_pos.x) + (end_pos.x - wall_x_positions[1])
	var wall_distance: float = absf(adjusted_end_pos - start_pos.x)

	if wall_distance < direct_distance:
		results.use_walls = true
		results.end = Vector2(start_pos.x + adjusted_end_pos, end_pos.y)
		results.wall_x_positions = wall_x_positions
	else:
		results.end = end_pos

	return results

func get_line_of_sight_positions(start_pos: Vector2, end_pos: Vector2, forces: int) -> PackedVector2Array:

	var results: PackedVector2Array = []
	if !should_wall_compensate(forces):
		results.push_back(start_pos)
		results.push_back(end_pos)
		return results

	var wall_results: Dictionary = get_shortest_path_walls(start_pos, end_pos)
	if !wall_results.use_walls:
		results.push_back(start_pos)
		results.push_back(end_pos)
		return results

	# Need to interpolate the y between the walls
	var wall_x_positions: PackedFloat32Array = wall_results.wall_x_positions
	var adjusted_end_pos: Vector2 = wall_results.end

	var total_distance: float = absf(adjusted_end_pos.x - start_pos.x)
	var accum_distance: float = 0.0

	results.push_back(start_pos)
	accum_distance += absf(wall_x_positions[0] - start_pos.x)
	var first_wall: Vector2 = Vector2(wall_x_positions[0], lerpf(start_pos.y, adjusted_end_pos.y, accum_distance / total_distance))
	results.push_back(first_wall)

	if wall_x_positions.size() > 1: # Warp
		results.push_back(Vector2(wall_x_positions[1], first_wall.y))

	results.push_back(end_pos)
	return results
#endregion

#region Opponent History
func _add_opponent_target_entry(opponent_data: Dictionary) -> OpponentTargetHistory:
	if !track_shot_history or !opponent_data.get("direct", false):
		return null
	
	var opponent: TankController = opponent_data.opponent
	var power: float = opponent_data.power
	var max_power: float = tank.max_power
	var angle: float = opponent_data.angle

	var opponent_target_history = _opponent_target_history.get_or_add(opponent.get_instance_id(), [])

	var target_data = OpponentTargetHistory.new()
	target_data.opponent = opponent
	target_data.my_position = aim_fulcrum_position
	target_data.opp_position = opponent.tank.global_position
	target_data.power = power
	target_data.angle = angle
	target_data.max_power = max_power

	last_opponent_history_entry = target_data
	opponent_target_history.append(target_data)

	return target_data

func get_opponent_target_history(opponent: TankController) -> Array:
	return _opponent_target_history.get(opponent.get_instance_id(), [])
	
#endregion

#region Utils

func _get_current_time_seconds() -> float:
	return game_level.game_timer.time_seconds

# TODO: This should be a helper on the game level and take into account walls
func _get_playable_x_extent() -> float:
	return get_viewport().get_visible_rect().size.x

#endregion
