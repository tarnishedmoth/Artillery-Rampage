class_name LobberAIBehavior extends AIBehavior

@export_group("Config")
@export_range(0.0, 1.0, 0.01) var aim_error_chance: float = 0.0

@export_group("Config")
@export_range(0.0, 60.0, 1.0) var aim_deviation_degrees: float = 15.0

@export_group("Config")
@export_range(0.0, 1.0, 0.05) var aim_power_pct: float = 0.2

@export_group("Config")
@export_range(0.0, 1.0, 0.05) var min_power_pct: float = 0.1

@export_group("Config")
@export_range(0.0, 10.0, 0.05) var error_reduction_exp: float = 2.0

@export_group("Config")
@export_range(0.0, 1.0, 0.05) var angles: Array[float] = [80.0, 75.0, 70.0, 65.0, 60.0, 55.0, 50.0, 45.0]

@export_group("Config")
@export_flags("Gravity", "Wind", "Warp Walls", "Elastic Walls") var forces_mask: int = Forces.Gravity | Forces.Wind

@export_group("Config")
@export_category("Hone")
@export_range(0.0, 1e9, 1.0, "or_greater") var max_pos_delta_history_usage: float = 10.0

@export_group("Config")
@export_category("Hone")
@export_range(0.0, 1e9, 1.0, "or_greater") var pow_per_dist: float = 3.0

@export_group("Config")
@export_category("Hone")
@export_range(0.1, 1.0, 0.01) var power_dist_exp: float = 0.85

@export_group("Config")
@export_category("Hone")
@export_range(0.0, 1e9, 1.0, "or_greater") var angle_per_power: float = 35.0 / 250.0

@export_group("Config")
@export_category("Hone")
@export_range(0.1, 1.0, 0.01) var angle_power_exp: float = 0.8

@export_group("Config")
@export_category("Hone")
@export_range(1.0, 2.0, 0.01) var time_exp: float = 2.0

@export_group("Config")
@export_category("Hone")
@export_range(0.1, 10.0, 0.01) var time_mult: float = 1.1

@export_group("Config")
@export_category("Hone")
@export_range(0.1, 2.0, 0.01) var delta_y_exp: float = 0.85

@export_group("Config")
@export_category("Hone")
@export_range(0.1, 1.0, 0.01) var max_dist_x_reduction_frac: float = 0.5

func _ready() -> void:
	super._ready()

	behavior_type = Enums.AIBehaviorType.Lobber
	track_shot_history = true

func execute(_tank: Tank) -> AIState:
	super.execute(_tank)
	
	var weapon_infos := get_weapon_infos()
	
	var best_opponent_data: Dictionary = _select_best_opponent()
	
	_modify_shot_based_on_history(best_opponent_data)
	_add_opponent_target_entry(best_opponent_data)

	var best_weapon: int = _select_best_weapon(best_opponent_data, weapon_infos)

	var perfect_shot_angle: float = best_opponent_data.angle
	var perfect_shot_power: float = best_opponent_data.power
	
	# Always try to miss on first shot at player if they have not taken a shot yet
	var player_has_not_fired:bool = _target_is_player_and_has_not_fired(best_opponent_data.opponent)
	var is_perfect_shot:bool = not player_has_not_fired and _is_perfect_shot(best_opponent_data)

	var angle_deviation: float = 0.0
	var power_deviation: float = 0.0

	if not is_perfect_shot:
		var shot_error: Dictionary = _default_get_shot_error(perfect_shot_power, perfect_shot_angle, best_opponent_data) if player_has_not_fired \
		 else _get_shot_error(perfect_shot_power, perfect_shot_angle, best_opponent_data)
		angle_deviation = shot_error.angle
		power_deviation = perfect_shot_power * shot_error.power_fraction
	
	# Max error decreases with each shot at opponent
	var shot_history = get_opponent_target_history(best_opponent_data.opponent)
	if shot_history.size() > 1:
		var error_reduction: float = pow(shot_history.size(), error_reduction_exp)
		angle_deviation /= error_reduction
		power_deviation /= error_reduction
	
	var angle := _clamp_final_angle(perfect_shot_angle, angle_deviation)
	var power := clampf(perfect_shot_power + power_deviation, tank.max_power * min_power_pct, _tank.max_power)
	
	print_debug("Lobber AI(%s): best_opponent=%s; best_weapon=%d; perfect_shot_angle=%f; angle_deviation=%f; perfect_shot_power=%f; power_deviation=%f"
		% [tank.owner.name, best_opponent_data.opponent.name, best_weapon, perfect_shot_angle, angle_deviation, perfect_shot_power, power_deviation])

	delete_weapon_infos(weapon_infos)
	
	return TargetActionState.new(best_opponent_data.opponent, best_weapon, power, angle, best_opponent_data, default_priority)

#region Overridable hook functions

func _is_perfect_shot(opponent_data: Dictionary) -> bool:
	return randf() > aim_error_chance

func _is_better_fallback_opponent(candidate: TankController, current_best: TankController, candidate_dist_sq: float, current_best_dist_sq) -> bool:
	return candidate_dist_sq < current_best_dist_sq

func _is_better_viable_opponent(candidate: TankController, current_best: TankController, candidate_dist_sq: float, current_best_dist_sq) -> bool:
	return candidate_dist_sq < current_best_dist_sq

func _default_get_shot_error(perfect_power: float, perfect_angle: float, opponent_data: Dictionary) -> Dictionary:
	return {
		angle = randf_range(-aim_deviation_degrees, aim_deviation_degrees),
		power_fraction = randf_range(-aim_power_pct, aim_power_pct)
	}
func _get_shot_error(perfect_power: float, perfect_angle: float, opponent_data: Dictionary) -> Dictionary:
	return _default_get_shot_error(perfect_power, perfect_angle, opponent_data)

#endregion

func _clamp_final_angle(perfect_shot_angle: float, deviation:float) -> float:

	var proposed_final_angle: float = perfect_shot_angle + deviation
	var proposed_final_angle_sgn: float = signf(proposed_final_angle)
	var perfect_shot_angle_sgn: float = signf(perfect_shot_angle)

	if absf(proposed_final_angle) < 1.0 and absf(perfect_shot_angle) > 1.0:
		# Invert the deviation so we don't nearly have a zero angle and possibly self destruct unintentionally
		print_debug("Lobber AI(%s): Inverting deviation to avoid uintended zero angle - initial_angle=%f; new_angle=%f; perfect_shot_angle=%f; deviation=%f" % \
			[tank.owner.name, proposed_final_angle, perfect_shot_angle - deviation, perfect_shot_angle, deviation])
		proposed_final_angle = perfect_shot_angle - deviation

	var final_angle: float = clampf(proposed_final_angle, tank.min_angle, tank.max_angle)
	print_debug("Lobber AI(%s): Clamping angle=%f -> %f" % [tank.owner.name, perfect_shot_angle + deviation, final_angle])

	return final_angle

func _modify_shot_based_on_history(shot: Dictionary) -> void:
	if !shot.direct:
		print_debug("Lobber AI(%s): No direct shot to %s - Ignoring shot history" % [tank.owner.name, shot.opponent.name])
		return
	
	# TODO: May need to make adjustments for walls based on adjusted_position from _select_best_opponent
	var opponent = shot.opponent
	var opponent_target_history = get_opponent_target_history(opponent)
	if !opponent_target_history:
		print_debug("Lobber AI(%s): No direct shot - Ignoring shot history" % [tank.owner.name])
		return

	var my_pos:Vector2 = aim_fulcrum_position
	var opp_pos:Vector2 = shot.opponent.tank.global_position

	# Compensate based on last shot but ignore if delta is too large
	var last_entry: OpponentTargetHistory = opponent_target_history.back()
	var last_pos_delta: float = last_entry.my_position.distance_to(my_pos)
	if last_pos_delta > max_pos_delta_history_usage:
		print_debug("Lobber AI(%s): Ignoring shot history - last_pos_delta=%f" % [tank.owner.name, last_pos_delta])
		return
	
	var last_opp_pos_delta: float = last_entry.opp_position.distance_to(opp_pos)
	if last_opp_pos_delta > max_pos_delta_history_usage:
		print_debug("Lobber AI(%s): Ignoring shot history - last_opp_pos_delta=%f" % [tank.owner.name, last_opp_pos_delta])
		return
	
	var delta_time: float = (last_entry.hit_time - last_entry.fire_time * last_entry.hit_count) / 1000.0

	# Feed in last entry data
	var current_power: float = last_entry.power
	var current_angle: float = turret_angle_to_global_angle(absf(last_entry.angle)) * signf(last_entry.angle)
	
	# Also consider angle sign alignment with shot direction
	# Positive angles are CW which would point right in the direction of positive x 
	var to_opp_aim:float = signf(last_entry.angle)
	
	var last_avg_hit_location: Vector2 = last_entry.hit_location / last_entry.hit_count
	var shot_deviation: Vector2 = last_avg_hit_location - last_entry.opp_position
	
	# Take into account the delta_y from hit point to target since if it hits higher up we probably are obstructed by terrain and so the actual x difference should be nerfed
	# Ideally too the angle should be increased to get over the hump - this should be handled ideally by the initial shot set up to do a raycast for different angles as well as the 
	# normal projectile simulation so that we have a good starting point that doesn't pound into a hill
	var shot_deviation_x: float = absf(shot_deviation.x)
	
	# y sign is negative if hit above target
	# Compensating for hitting early or late based on terrain elevation differences
	# Allow flipping the sign on the min side if end up "tunneling under" the enemy when underhitting as it will 
	# eventually report an incorrect "long shot".  Maybe capturing the x at the height of the target would be a better approach
	var shot_deviation_sign_y:float = signf(shot_deviation.y)
	var adjusted_shot_y:float = pow(shot_deviation_sign_y * shot_deviation.y, delta_y_exp)
	var raw_adjustment_value:float = shot_deviation_x - shot_deviation_sign_y * adjusted_shot_y
	var shot_deviation_dist : float = maxf(shot_deviation_x - adjusted_shot_y, shot_deviation_x * max_dist_x_reduction_frac)
	
	var is_long: bool = shot_deviation.x * signf(raw_adjustment_value) * to_opp_aim > 0.0
	
	# TODO: Easing?
	var power_dev: float = pow_per_dist * pow(shot_deviation_dist, power_dist_exp) / pow(time_mult * delta_time, time_exp)

	if is_long:
		power_dev *= -1.0
	
	var min_power:float = tank.max_power * min_power_pct
	var new_power: float = current_power + power_dev
	var new_angle:float = current_angle

	var angle_change:int = 0
	var angle_dev:float = 0.0
	var power_wrap:float = 0.0
	
	# This can also occur if tank becomes damaged since the last shot and now has a lower max power
	if new_power > tank.max_power:
		power_wrap = new_power - tank.max_power
		new_power = tank.max_power
		# Also decrease_angle
		angle_change = -1
	elif new_power < min_power:
		power_wrap = min_power - new_power
		new_power = min_power
		# Also increase angle
		angle_change = 1
	
	if angle_change:
		angle_dev = angle_per_power * pow(power_wrap, angle_power_exp)

		if angle_change < 0:
			angle_dev *= -1.0
		
		var current_angle_sgn: float = signf(current_angle)
		new_angle = current_angle + current_angle_sgn * angle_dev
		var new_angle_abs: float = absf(new_angle)
		
		var max_angle: float = angles.max()
		var min_angle: float = angles.min()
		
		# Wrap around - assuming don't need to do it multiple times but clamp if that happens
		if new_angle_abs > max_angle:
			new_angle = -current_angle_sgn * clampf(max_angle - (new_angle_abs - max_angle), min_angle, max_angle)
		elif new_angle_abs < min_angle:
			new_angle = -current_angle_sgn * clampf(max_angle - (min_angle - new_angle_abs), min_angle, max_angle)

	# TODO: The convenience function should handle the sign-ing for us
	new_angle = global_angle_to_turret_angle(absf(new_angle)) * signf(new_angle)
	
	print_debug("Lobber AI(%s): Adjusting shot based on history - dt=%f; orig_power=%f; new_power=%f; orig_angle=%f; new_angle=%f; shot_deviation=%s; is_long=%s; power_dev=%f; angle_change=%d; angle_dev=%f; power_wrap=%f"
		% [tank.owner.name, delta_time, current_power, new_power, last_entry.angle, new_angle, shot_deviation, str(is_long), power_dev, angle_change, angle_dev, power_wrap])

	shot.power = new_power
	shot.angle = new_angle
	
class TargetActionState extends AIState:
	var _opponent: TankController
	var _weapon:int 
	var _power:float
	var _angle:float

	func _init(opponent: TankController, weapon: int, power:float,  angle: float, opponent_data:Dictionary, default_priority: int):
		self._opponent = opponent
		self._weapon = weapon
		self._power = power
		self._angle = angle

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

	var closest_direct_opponent: TankController = null
	var closest_direct_opponent_pos: Vector2 = Vector2.ZERO

	var closest_opponent: TankController = null
	var closest_opponent_position: Vector2 = Vector2.ZERO

	const sentinel_dist:float = 1e9
	var closest_direct_shot_distance: float = sentinel_dist
	var closest_distance:float = sentinel_dist
	var closest_targeting_values: Dictionary = {}
	
	# TODO: May need to take into account weapon modifiers for launch speed but right now launch speed == power
	var launch_props = AIBehavior.LaunchProperties.new()
	launch_props.power_speed_mult = 1.0
	# TODO: if we change the mass of the projectiles will need to figure out how to read that here which would require selecting a weapon first
	launch_props.mass = 1.0

	# If there is no direct shot opponent, then we will just return the closest opponent
	for opponent in opponents:
		var adjusted_opponent_position: Vector2 = get_target_end_walls(tank.global_position, opponent.tank.global_position, forces_mask)

		var distance: float = tank.global_position.distance_squared_to(adjusted_opponent_position)

		if is_equal_approx(closest_distance, sentinel_dist) or _is_better_fallback_opponent(opponent, closest_opponent, distance, closest_distance):
			closest_distance = distance
			closest_opponent = opponent
			closest_opponent_position = adjusted_opponent_position

		var targeting_values: Dictionary = _get_power_and_angle_to_opponent(opponent, launch_props)

		if targeting_values and (is_equal_approx(closest_direct_shot_distance, sentinel_dist) or _is_better_viable_opponent(opponent, closest_direct_opponent, distance, closest_direct_shot_distance)):
			closest_direct_shot_distance = distance
			closest_direct_opponent = opponent
			closest_direct_opponent_pos = adjusted_opponent_position
			closest_targeting_values = targeting_values
	
	if closest_direct_opponent:
		var transformed_angle = global_angle_to_turret_angle(closest_targeting_values.angle)
		var angle: float = transformed_angle if closest_direct_opponent_pos.x >= tank.global_position.x else -transformed_angle

		return { direct = true, opponent = closest_direct_opponent, angle = angle, power = closest_targeting_values.power, adjusted_position = closest_direct_opponent_pos, distance = sqrt(closest_direct_shot_distance) }

	# Need to determine where we will hit with the fallback approach as this needs to be taken into account with weapon selection
	else:
		var transformed_angle = global_angle_to_turret_angle(angles.min())

		var angle: float = transformed_angle if closest_opponent_position.x >= tank.global_position.x else -transformed_angle
		var dir: Vector2 = aim_angle_to_world_direction(angle)
		# Determine point we hit in that direction
		var ray_cast_result: Dictionary = check_world_collision(tank.turret.global_position, tank.turret.global_position + dir * 10000.0)

		var result : Dictionary =  { direct = false, opponent = closest_opponent, angle = angle, power = tank.max_power, adjusted_position = closest_opponent_position, distance = sqrt(closest_distance) }

		if ray_cast_result:
			result.hit_position = ray_cast_result.position

		return result

func _get_power_and_angle_to_opponent(opponent: TankController, launch_props: AIBehavior.LaunchProperties) -> Dictionary:
	var target: Vector2 = opponent.tank.global_position

	for angle in angles:
		var power := get_power_for_target_and_angle(target, angle, launch_props, forces_mask)
		if power > 0.0:
			return { angle = angle, power = power }
	return {}

# TODO: Copying initially from brute_ai - if this is what we want to do for most AI we can push up to base class
func _select_best_weapon(opponent_data: Dictionary, weapon_infos: Array[AIBehavior.WeaponInfo]) -> int:
	
	# If only have one weapon then immediately return
	if tank.weapons.is_empty():
		push_warning("Lobber AI(%s): No weapons available! - returning 0" % [tank.owner.name])
		# Return 0 instead of -1 in case issue resolves itself by the time we try to shoot
		return 0
	if tank.weapons.size() == 1:
		print_debug("Lobber AI(%s): Only 1 weapon available - returning 0" % [tank.owner.name])
		return 0
	
	var target_distance: float

	# We are going to hit something other than opponent tank first
	if opponent_data.has("hit_position"):
		target_distance = tank.global_position.distance_to(opponent_data.hit_position)
	else:
		target_distance = tank.global_position.distance_to(opponent_data.opponent.tank.global_position)

	# Select most powerful available weapon that won't cause self-damage
	var best_weapon:int = -1
	var best_score:float = 0.0

	for i in range(weapon_infos.size()):
		var weapon_info: AIBehavior.WeaponInfo = weapon_infos[i]
		var weapon: Weapon = weapon_info.weapon
		var projectile : WeaponProjectile = weapon_info.projectile_prototype
		
		if projectile and target_distance > projectile.max_falloff_distance:
			var score : float = projectile.max_damage * projectile.max_damage * projectile.min_falloff_distance * projectile.max_falloff_distance * weapon.ammo_used_per_shot
			print_debug("Lobber AI(%s): weapon(%d)=%s; score=%f" % [tank.owner.name, i, weapon.name, score])
			if score > best_score:
				best_score = score
				best_weapon = i

	if best_weapon != -1:
		print_debug("Lobber AI(%s): selected best_weapon=%d/%d; score=%f" % [tank.owner.name, best_weapon, weapon_infos.size(), best_score])
		return best_weapon
	
	# Fallback to random weapon
	print_debug("Lobber AI(%s): Could not find viable weapon - falling back to random selection out of %d candidates" % [tank.owner.name, tank.weapons.size()])

	return randi_range(0, tank.weapons.size() - 1)
