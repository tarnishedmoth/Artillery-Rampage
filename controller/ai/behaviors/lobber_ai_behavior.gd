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

class OpponentTargetHistory:
	var opponent: TankController
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
	_add_opponent_target_entry(best_opponent_data)

	var best_weapon: int = _select_best_weapon(best_opponent_data, weapon_infos)

	var perfect_shot_angle: float = best_opponent_data.angle
	var angle_deviation: float = 0.0 if randf() > aim_error_chance else perfect_shot_angle + randf_range(-aim_deviation_degrees, aim_deviation_degrees)
	
	var perfect_shot_power: float = best_opponent_data.power
	var power_deviation: float = 0.0 if randf() > aim_error_chance else perfect_shot_power + randf_range(-aim_power_pct, aim_power_pct)

	var angle := clampf(perfect_shot_angle + angle_deviation, _tank.min_angle, _tank.max_angle)
	var power := clampf(perfect_shot_power + power_deviation, tank.max_power * min_power_pct, _tank.max_power)
	
	print_debug("Brute AI(%s): best_opponent=%s; best_weapon=%d; perfect_shot_angle=%f; angle_deviation=%f; perfect_shot_power=%f; power_deviation=%f"
		% [tank.name, best_opponent_data.opponent.name, best_weapon, perfect_shot_angle, angle_deviation, perfect_shot_power, power_deviation])

	delete_weapon_infos(weapon_infos)
	
	return TargetActionState.new(best_opponent_data.opponent, best_weapon, power, angle)

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

func _add_opponent_target_entry(opponent_data: Dictionary) -> void:
	# Even blind shots may provide useful data for power and angle feedback
	# if !opponent_data.direct:
	# 	return
	
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
	target_data.power = power
	target_data.angle = angle
	target_data.max_power = max_power

	last_opponent_history_entry = target_data

	opponent_target_history.append(target_data)

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	if projectile.owner_tank != tank:
		return
	
	print_debug("LobberAIBehavior(%s): Projectile Fired=%s" % [tank.name, projectile.name])

	# Need to bind the extra projectile argument to connect
	projectile.completed_lifespan.connect(_on_projectile_destroyed.bind([projectile, last_opponent_history_entry]))

# Bind arguments are passed as an array
func _on_projectile_destroyed(args: Array) -> void:
	var projectile: WeaponProjectile = args[0]
	var opponent_history_entry: OpponentTargetHistory = args[1]

	print_debug("LobberAIBehavior(%s): Projectile Destroyed=%s" % [tank.name, projectile.name])

	opponent_history_entry.hit_count += 1
	opponent_history_entry.hit_location += projectile.global_position
