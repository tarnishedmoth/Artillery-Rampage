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
@export_range(0.0, 1.0, 0.05) var angles: Array[float] = [80.0, 75.0, 70.0, 65.0, 60.0, 55.0, 50.0, 45.0]

@export_group("Config")
@export_flags("Gravity", "Wind") var forces_mask: int = Forces.All

@export_group("Config")
@export_category("Hone")
@export_range(0.0, 1e9, 1.0, "or_greater") var max_pos_delta_history_usage: float = 10.0

@export_group("Config")
@export_category("Hone")
@export_range(0.0, 1e9, 1.0, "or_greater") var pow_per_dist: float = 3.0

@export_group("Config")
@export_category("Hone")
@export_range(0.1, 1.0, 0.01) var power_dist_exp: float = 0.9

@export_group("Config")
@export_category("Hone")
@export_range(0.0, 1e9, 1.0, "or_greater") var angle_per_dist: float = 45.0 / 1000.0

@export_group("Config")
@export_category("Hone")
@export_range(0.1, 1.0, 0.01) var angle_dist_exp: float = 0.75

# TODO: May push this up to base class and have it toggleable on/off to be reusable for other AI types (except Rando one)
class OpponentTargetHistory:
	var opponent: TankController
	var my_position: Vector2
	var opp_position: Vector2
	var hit_location: Vector2 = Vector2.ZERO
	var hit_count: int # For multi-shot
	var power: float
	var max_power: float
	var angle: float

# Dictionary of opponent to Array[OpponentTargetHistory]
var _opponent_target_history: Dictionary = {}
var last_opponent_history_entry: OpponentTargetHistory

func _ready() -> void:
	super._ready()

	# Listen to track opponent targeting feedback
	GameEvents.projectile_fired.connect(_on_projectile_fired)

func execute(_tank: Tank) -> AIState:
	super.execute(_tank)
	
	var weapon_infos := get_weapon_infos()
	
	var best_opponent_data: Dictionary = _select_best_opponent()
	_modify_shot_based_on_history(best_opponent_data)

	last_opponent_history_entry = _add_opponent_target_entry(best_opponent_data)

	var best_weapon: int = _select_best_weapon(best_opponent_data, weapon_infos)

	var perfect_shot_angle: float = best_opponent_data.angle
	var angle_deviation: float = 0.0 if randf() > aim_error_chance else perfect_shot_angle + randf_range(-aim_deviation_degrees, aim_deviation_degrees)
	
	var perfect_shot_power: float = best_opponent_data.power
	var power_deviation: float = 0.0 if randf() > aim_error_chance else perfect_shot_power + randf_range(-aim_power_pct, aim_power_pct)

	var angle := clampf(perfect_shot_angle + angle_deviation, _tank.min_angle, _tank.max_angle)
	var power := clampf(perfect_shot_power + power_deviation, tank.max_power * min_power_pct, _tank.max_power)
	
	print_debug("Lobber AI(%s): best_opponent=%s; best_weapon=%d; perfect_shot_angle=%f; angle_deviation=%f; perfect_shot_power=%f; power_deviation=%f"
		% [name, best_opponent_data.opponent.name, best_weapon, perfect_shot_angle, angle_deviation, perfect_shot_power, power_deviation])

	delete_weapon_infos(weapon_infos)
	
	return TargetActionState.new(best_opponent_data.opponent, best_weapon, power, angle)

func _modify_shot_based_on_history(shot: Dictionary) -> void:
	if !shot.direct:
		print_debug("Lobber AI(%s): No direct shot to %s - Ignoring shot history" % [name, shot.opponent.name])
		return
	
	var opponent = shot.opponent
	var opponent_target_history = _opponent_target_history.get(opponent)
	if !opponent_target_history:
		print_debug("Lobber AI(%s): No direct shot - Ignoring shot history" % [name])
		return

	var my_pos:Vector2 = aim_fulcrum_position
	var opp_pos:Vector2 = shot.opponent.tank.global_position

	var to_opp:Vector2 = opp_pos - my_pos

	# Compensate based on last shot but ignore if delta is too large
	var last_entry: OpponentTargetHistory = opponent_target_history.back()
	var last_pos_delta: float = last_entry.my_position.distance_to(my_pos)
	if last_pos_delta > max_pos_delta_history_usage:
		print_debug("Lobber AI(%s): Ignoring shot history - last_pos_delta=%f" % [name, last_pos_delta])
		return
	
	var last_opp_pos_delta: float = last_entry.opp_position.distance_to(opp_pos)
	if last_opp_pos_delta > max_pos_delta_history_usage:
		print_debug("Lobber AI(%s): Ignoring shot history - last_opp_pos_delta=%f" % [name, last_opp_pos_delta])
		return
	
	# Feed in last entry data
	var current_power: float = last_entry.power
	var current_angle: float = turret_angle_to_global_angle(absf(last_entry.angle)) * signf(last_entry.angle)
	
	# Also consider angle sign alignment with shot direction
	# Positive angles are CW which would point right in the direction of positive x 
	var to_opp_aim:Vector2 = to_opp * signf(last_entry.angle) * signf(to_opp.x)
	
	var shot_deviation: Vector2 = last_entry.hit_location - last_entry.opp_position
	var shot_deviation_dist : float = shot_deviation.length()
	
	var is_long: bool = shot_deviation.dot(to_opp_aim) > 0.0
	
	# TODO: Easing?
	var power_dev: float = pow_per_dist * pow(shot_deviation_dist, power_dist_exp)
	if is_long:
		power_dev *= -1.0
	
	var min_power:float = tank.max_power * min_power_pct
	var new_power: float = current_power + power_dev
	var new_angle:float = current_angle

	var angle_change:int = 0
	var angle_dev:float = 0.0

	if new_power > tank.max_power:
		new_power = tank.max_power
		# Also decrease_angle
		angle_change = -1
	elif new_power < min_power:
		new_power = min_power
		# Also increase angle
		angle_change = 1
	
	if angle_change:
		angle_dev = angle_per_dist * pow(shot_deviation_dist, angle_dist_exp)
		if angle_change < 0:
			angle_dev *= -1.0
		var current_angle_sgn: float = signf(current_angle)
		new_angle = current_angle + current_angle_sgn * angle_dev
		var new_angle_abs: float = absf(new_angle)
		
		var max_angle: float = angles.max()
		var min_angle: float = angles.min()
		
		# Wrap around - assuming don't need to do it multiple times
		if new_angle_abs > max_angle:
			new_angle = -current_angle_sgn * (max_angle - (new_angle_abs - max_angle))
		elif new_angle_abs < min_angle:
			new_angle = -current_angle_sgn * (max_angle - (min_angle - new_angle_abs))

	# TODO: The convenience function should handle the sign-ing for us
	new_angle = global_angle_to_turret_angle(absf(new_angle)) * signf(new_angle)
	
	print_debug("Lobber AI(%s): Adjusting shot based on history - last_pos_delta=%f; orig_power=%f; new_power=%f; orig_angle=%f; new_angle=%f; last_opp_pos_delta=%f; shot_deviation=%s; is_long=%s; power_dev=%f; angle_change=%d; angle_dev=%f"
		% [name, last_pos_delta, current_power, new_power, current_angle, new_angle, last_opp_pos_delta, shot_deviation, str(is_long), power_dev, angle_change, angle_dev])

	shot.power = new_power
	shot.angle = new_angle
	
class TargetActionState extends AIState:
	var _opponent: TankController
	var _weapon:int 
	var _power:float
	var _angle:float

	func _init(opponent: TankController, weapon: int, power:float,  angle: float):
		self._opponent = opponent
		self._weapon = weapon
		self._power = power
		self._angle = angle

	func execute(_tank: Tank) -> TankActionResult:
		return TankActionResult.new(
			 _power,
			 _angle,
			 _weapon
		)

func _select_best_opponent() -> Dictionary:
	var opponents: Array[TankController] = get_opponents()

	var closest_direct_opponent: TankController = null
	var closest_opponent: TankController = null

	var closest_direct_shot_distance: float = 1e9
	var closest_distance:float = 1e9
	var closest_targeting_values: Dictionary = {}
	
	# TODO: May need to take into account weapon modifiers for launch speed but right now launch speed == power
	var launch_props = AIBehavior.LaunchProperties.new()
	launch_props.power_speed_mult = 1.0
	# TODO: if we change the mass of the projectiles will need to figure out how to read that here which would require selecting a weapon first
	launch_props.mass = 1.0

	# If there is no direct shot opponent, then we will just return the closest opponent
	for opponent in opponents:
		var distance: float = tank.global_position.distance_squared_to(opponent.tank.global_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_opponent = opponent

		var targeting_values: Dictionary = _get_power_and_angle_to_opponent(opponent, launch_props)
		if targeting_values and distance < closest_direct_shot_distance:
			closest_direct_shot_distance = distance
			closest_direct_opponent = opponent
			closest_targeting_values = targeting_values
	
	if closest_direct_opponent:
		var transformed_angle = global_angle_to_turret_angle(closest_targeting_values.angle)
		var angle: float = transformed_angle if closest_direct_opponent.tank.global_position.x >= tank.global_position.x else -transformed_angle

		return { direct = true, opponent = closest_direct_opponent, angle = angle, power = closest_targeting_values.power }

	# Need to determine where we will hit with the fallback approach as this needs to be taken into account with weapon selection
	else:
		var transformed_angle = global_angle_to_turret_angle(angles.min())

		var angle: float = transformed_angle if closest_opponent.tank.global_position.x >= tank.global_position.x else -transformed_angle
		var dir: Vector2 = aim_angle_to_world_direction(angle)
		# Determine point we hit in that direction
		var ray_cast_result: Dictionary = check_world_collision(tank.turret.global_position, tank.turret.global_position + dir * 10000.0)

		var result : Dictionary =  { direct = false, opponent = closest_opponent, angle = angle, power = tank.max_power }

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
		push_warning("Lobber AI(%s): No weapons available! - returning 0" % [name])
		# Return 0 instead of -1 in case issue resolves itself by the time we try to shoot
		return 0
	if tank.weapons.size() == 1:
		print_debug("Lobber AI(%s): Only 1 weapon available - returning 0" % [name])
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
			print_debug("Lobber AI(%s): weapon(%d)=%s; score=%f" % [name, i, weapon.name, score])
			if score > best_score:
				best_score = score
				best_weapon = i

	if best_weapon != -1:
		print_debug("Lobber AI(%s): selected best_weapon=%d/%d; score=%f" % [name, best_weapon, weapon_infos.size(), best_score])
		return best_weapon
	
	# Fallback to random weapon
	print_debug("Lobber AI(%s): Could not find viable weapon - falling back to random selection out of %d candidates" % [name, tank.weapons.size()])

	return randi_range(0, tank.weapons.size() - 1)

func _add_opponent_target_entry(opponent_data: Dictionary) -> OpponentTargetHistory:
	if !opponent_data.direct:
		return null
	
	var opponent: TankController = opponent_data.opponent
	var power: float = opponent_data.power
	var max_power: float = tank.max_power
	var angle: float = opponent_data.angle

	var opponent_target_history = _opponent_target_history.get(opponent)
	if !opponent_target_history:
		opponent_target_history = []
		_opponent_target_history[opponent] = opponent_target_history

	var target_data = OpponentTargetHistory.new()
	target_data.opponent = opponent
	target_data.my_position = aim_fulcrum_position
	target_data.opp_position = opponent.tank.global_position
	target_data.power = power
	target_data.angle = angle
	target_data.max_power = max_power

	opponent_target_history.append(target_data)

	return target_data

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	if projectile.owner_tank != tank:
		return
	
	print_debug("Lobber AIBehavior(%s): Projectile Fired=%s" % [name, projectile.name])

	if !last_opponent_history_entry:
		print_debug("Lobber AIBehavior(%s): Ignoring blind fire shot for projectile=%s" % [name, projectile.name])
		return

	# Need to bind the extra projectile argument to connect
	projectile.completed_lifespan.connect(_on_projectile_destroyed.bind([projectile, last_opponent_history_entry]))

# Bind arguments are passed as an array
func _on_projectile_destroyed(args: Array) -> void:
	var projectile: WeaponProjectile = args[0]
	var opponent_history_entry: OpponentTargetHistory = args[1]

	print_debug("Lobber AIBehavior(%s): Projectile Destroyed=%s" % [name, projectile.name])

	opponent_history_entry.hit_count += 1
	opponent_history_entry.hit_location += projectile.global_position
