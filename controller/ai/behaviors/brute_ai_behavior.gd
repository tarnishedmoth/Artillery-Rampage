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
	var power: float = _modify_power(best_opponent_data.opponent)

	best_opponent_data.power = power
	_add_opponent_target_entry(best_opponent_data)

	var best_weapon: int = _select_best_weapon(best_opponent_data, weapon_infos)

	var perfect_shot_angle: float = best_opponent_data.angle

	var is_perfect_shot:bool = not _target_is_player_and_has_not_fired(best_opponent_data.opponent) and randf() > aim_error_chance

	var angle_deviation: float = 0.0 if is_perfect_shot else perfect_shot_angle + randf_range(-aim_deviation_degrees, aim_deviation_degrees)
	
	var angle := clampf(perfect_shot_angle + angle_deviation, _tank.min_angle, _tank.max_angle)
	
	print_debug("Brute AI(%s): best_opponent=%s; best_weapon=%d; perfect_shot_angle=%f; angle_deviation=%f; power=%f" 
		% [tank.name, best_opponent_data.opponent.name, best_weapon, perfect_shot_angle, angle_deviation, power])

	delete_weapon_infos(weapon_infos)
	
	return TargetActionState.new(best_opponent_data.opponent, best_weapon, angle, power, best_opponent_data, default_priority)

func _modify_power(opponent: TankController) -> float:
	if ! track_shot_history:
		return tank.max_power

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
		if opponent_data.direct:
			priority += 100
		elif !opponent_data.hit_position:
			priority += 10

	func execute(tank: Tank) -> TankActionResult:
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

		var distance: float = tank.global_position.distance_squared_to(opponent.tank.global_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_opponent = opponent

		if result.test and distance < closest_direct_shot_distance:
			closest_direct_shot_distance = distance
			closest_direct_opponent = opponent
			closest_direct_angle = result.aim_angle
	
	if closest_direct_opponent:
		return { direct = true, opponent = closest_direct_opponent, angle = closest_direct_angle }

	# Need to determine where we will hit with the fallback approach as this needs to be taken into account with weapon selection
	else:
		var angle : float = get_direct_aim_angle_to(closest_opponent, launch_props)
		var dir: Vector2 = aim_angle_to_world_direction(angle)
		# Determine point we hit in that direction
		var ray_cast_result: Dictionary = check_world_collision(tank.turret.global_position, tank.turret.global_position + dir * 10000.0)

		var result : Dictionary =  { opponent = closest_opponent, angle = angle }

		if ray_cast_result:
			result.hit_position = ray_cast_result.position

		return result

func _select_best_weapon(opponent_data: Dictionary, weapon_infos: Array[AIBehavior.WeaponInfo]) -> int:
	
	# If only have one weapon then immediately return
	if tank.weapons.is_empty():
		push_warning("BruteAI(%s): No weapons available! - returning 0" % [tank.name])
		# Return 0 instead of -1 in case issue resolves itself by the time we try to shoot
		return 0
	if tank.weapons.size() == 1:
		print_debug("BruteAI(%s): Only 1 weapon available - returning 0" % [tank.name])
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
			print_debug("BruteAI(%s): weapon(%d)=%s; score=%f" % [tank.name, i, weapon.name, score])
			if score > best_score:
				best_score = score
				best_weapon = i

	if best_weapon != -1:
		print_debug("BruteAI(%s): selected best_weapon=%d/%d; score=%f" % [tank.name, best_weapon, weapon_infos.size(), best_score])
		return best_weapon
	
	# Fallback to random weapon
	print_debug("BruteAI(%s): Could not find viable weapon - falling back to random selection out of %d candidates" % [tank.name, tank.weapons.size()])

	return randi_range(0, tank.weapons.size() - 1)
