class_name BruteAIBehavior extends AIBehavior

@export_group("Config")
@export_range(0.0, 1.0, 0.01) var aim_error_chance: float = 0.0

@export_group("Config")
@export_range(0.0, 60.0, 1.0) var aim_deviation_degrees: float = 15.0

@export_group("Config")
@export_flags("Gravity", "Wind", "Warp Walls", "Elastic Walls") var forces_mask: int = Forces.Gravity | Forces.Wind

@export_group("Config")
@export_range(0.0, 1.0, 0.01) var power_attempt_reduction: float = 0.0

@export_group("Config")
@export_range(0.1, 1.0, 0.01) var min_power_fraction: float = 1.0

var opponent_power_history: Dictionary = {}

func _ready() -> void:
	super._ready()
	behavior_type = Enums.AIBehaviorType.Brute

	if power_attempt_reduction > 0.0:
		track_shot_history = true
	
# TODO: Maybe don't need the tank parameter
func execute(_tank: Tank) -> AIState:
	super.execute(_tank)
	
	var weapon_infos := get_weapon_infos()
	
	var best_opponent_data: Dictionary = _select_best_opponent()
	if not best_opponent_data:
		return AIState.MaxPowerState.new(_tank, randi_range(0, weapon_infos.size() - 1))

	var power: float = _modify_power(best_opponent_data)

	best_opponent_data.power = power
	_add_opponent_target_entry(best_opponent_data)

	var best_weapon: int = select_best_weapon(best_opponent_data, weapon_infos)

	var perfect_shot_angle: float = best_opponent_data.angle

	var player_has_not_fired:bool = _target_is_player_and_has_not_fired(best_opponent_data.opponent)
	var is_perfect_shot:bool = not player_has_not_fired and _is_perfect_shot(best_opponent_data)

	var angle_deviation: float = 0.0 if is_perfect_shot else perfect_shot_angle + \
		(_default_get_aim_error(perfect_shot_angle, best_opponent_data) if player_has_not_fired \
		else get_aim_error(perfect_shot_angle, best_opponent_data))
	
	var angle := clampf(perfect_shot_angle + angle_deviation, _tank.min_angle, _tank.max_angle)
	
	print_debug("Brute AI(%s): best_opponent=%s; best_weapon=%d; perfect_shot_angle=%f; angle_deviation=%f; power=%f" 
		% [tank.name, best_opponent_data.opponent.name, best_weapon, perfect_shot_angle, angle_deviation, power])

	delete_weapon_infos(weapon_infos)
	
	return TargetActionState.new(best_opponent_data.opponent, best_weapon, angle, power, best_opponent_data, default_priority)

#region Overridable hook functions

func _is_perfect_shot(_opponent_data: Dictionary) -> bool:
	return randf() > aim_error_chance

func _is_better_fallback_opponent(_candidate: TankController, _current_best: TankController, candidate_dist_sq: float, current_best_dist_sq) -> bool:
	return candidate_dist_sq < current_best_dist_sq

func _is_better_viable_opponent(_candidate: TankController, _current_best: TankController, candidate_dist_sq: float, current_best_dist_sq) -> bool:
	return candidate_dist_sq < current_best_dist_sq

func _default_get_aim_error(_perfect_angle: float, _opponent_data: Dictionary) -> float:
	return randf_range(-aim_deviation_degrees, aim_deviation_degrees)

func get_aim_error(perfect_angle: float, opponent_data: Dictionary) -> float:
	return _default_get_aim_error(perfect_angle, opponent_data)

#endregion

func _modify_power(opponent_data: Dictionary) -> float:
	if not track_shot_history or not opponent_data.get("direct", false):
		return tank.max_power
		
	var opponent: TankController = opponent_data.opponent
	var opponent_history: Array = get_opponent_target_history(opponent)
	if !opponent_history:
		print_debug("Brute AI(%s): No direct shot - Ignoring shot history" % [tank.owner.name])
		return tank.max_power

	# Dumbed down version of lobber_ai_behavior
	var last_entry: OpponentTargetHistory = opponent_history.back()
	var last_avg_hit_location: Vector2 = last_entry.hit_location / last_entry.hit_count
	var shot_deviation: Vector2 = last_avg_hit_location - last_entry.opp_position
	# Positive angles are CW which would point right in the direction of positive x 
	var to_opp_aim:float = signf(last_entry.angle)

	var shot_deviation_x: float = absf(shot_deviation.x)
	var is_long: bool = shot_deviation.x * signf(shot_deviation_x) * to_opp_aim > 0.0

	var power_history: PackedFloat32Array = opponent_power_history.get_or_add(opponent.get_instance_id(), PackedFloat32Array())

	var power:float
	
	if is_long:
		var last_power:float = power_history[power_history.size() - 1] if !power_history.is_empty() else tank.max_power
		power = maxf(last_power * power_attempt_reduction, tank.max_power * min_power_fraction)
	else:
		print_debug("Brute AI(%s): Shot missed close - not changing shot power" % [tank.owner.name])
		# Interpolate last two values
		var power_entry_count: int = power_history.size()
		match power_entry_count:
			0:
				return tank.max_power
			1:
				power = lerpf(tank.max_power, power_history[0], 0.5)
			_: # > 1
				power = lerpf(power_history[power_entry_count - 2], power_history[power_entry_count - 1], 0.5)

	power_history.push_back(power)

	return power

class TargetActionState extends AIState:
	var _opponent: TankController
	var _weapon:int 
	var _angle:float
	var _power: float

	func _init(opponent: TankController, weapon: int, angle: float, power:float, opponent_data: Dictionary, default_priority: int):
		self._opponent = opponent
		self._weapon = weapon
		self._angle = angle
		self._power = power

		priority = default_priority
		if opponent_data.get("direct", false):
			priority += 100
		elif !opponent_data.has("hit_position"):
			priority += 10

	func execute(_tank: Tank) -> TankActionResult:
		return TankActionResult.new(
			 _power,
			 _angle,
			 _weapon
		)

func _select_best_opponent() -> Dictionary:
	var opponents: Array[TankController] = get_opponents()

	if not opponents:
		push_warning("BruteAI(%s): No opponents found!" % [tank.name])
		return {}

	var closest_direct_opponent: TankController = null
	var closest_opponent: TankController = null
	var closest_direct_opponent_pos: Vector2 = Vector2.ZERO
	var closest_opponent_position: Vector2 = Vector2.ZERO

	const sentinel_dist:float = 1e9
	var closest_direct_shot_distance: float = sentinel_dist
	var closest_distance:float = sentinel_dist
	var closest_direct_angle:float = 0.0
	
	# TODO: May need to take into account weapon modifiers for launch speed but right now launch speed == power
	var launch_props = AIBehavior.LaunchProperties.new()
	launch_props.power_speed_mult = 1.0
	launch_props.speed = tank.max_power
	# TODO: if we change the mass of the projectiles will need to figure out how to read that here which would require selecting a weapon first
	launch_props.mass = 1.0

	# If there is no direct shot opponent, then we will just return the closest opponent
	for opponent in opponents:
		var result: Dictionary = has_direct_shot_to(opponent, launch_props, forces_mask)

		var distance: float = tank.global_position.distance_squared_to(result.adjusted_opponent_position)

		if is_equal_approx(closest_distance, sentinel_dist) or _is_better_fallback_opponent(opponent, closest_opponent, distance, closest_distance):
			closest_distance = distance
			closest_opponent = opponent
			closest_opponent_position = result.adjusted_opponent_position

		if result.test and (is_equal_approx(closest_direct_shot_distance, sentinel_dist) or _is_better_viable_opponent(opponent, closest_direct_opponent, distance, closest_direct_shot_distance)):
			closest_direct_shot_distance = distance
			closest_direct_opponent = opponent
			closest_direct_angle = result.aim_angle
			closest_direct_opponent_pos = result.adjusted_opponent_position
	
	if closest_direct_opponent:
		return { direct = true, opponent = closest_direct_opponent, angle = closest_direct_angle, adjusted_position = closest_direct_opponent_pos, distance = sqrt(closest_direct_shot_distance) }

	# Need to determine where we will hit with the fallback approach as this needs to be taken into account with weapon selection
	else:
		var angle : float = get_direct_aim_angle_to(closest_opponent, launch_props)
		var dir: Vector2 = aim_angle_to_world_direction(angle)
		# Determine point we hit in that direction
		var ray_cast_result: Dictionary = check_world_collision(tank.turret.global_position, tank.turret.global_position + dir * 10000.0)

		var result : Dictionary =  { opponent = closest_opponent, angle = angle, adjusted_position = closest_opponent_position, distance = sqrt(closest_distance) }

		if ray_cast_result:
			result.hit_position = ray_cast_result.position

		return result
