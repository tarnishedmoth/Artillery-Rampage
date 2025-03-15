class_name BruteAIBehavior extends AIBehavior

@export_group("Config")
@export_range(0.0, 1.0, 0.01) var aim_error_chance: float = 0.0

@export_group("Config")
@export_range(0.0, 60.0, 1.0) var aim_deviation_degrees: float = 15.0

@export_group("Config")
@export_flags("Gravity", "Wind", "Warp Walls", "Elastic Walls") var forces_mask: int = Forces.Gravity | Forces.Wind


# TODO: Maybe don't need the tank parameter
func execute(_tank: Tank) -> AIState:
	super.execute(_tank)
	
	var weapon_infos := get_weapon_infos()
	
	var best_opponent_data: Dictionary = _select_best_opponent()
	var best_weapon: int = _select_best_weapon(best_opponent_data, weapon_infos)

	var perfect_shot_angle: float = best_opponent_data.angle

	var is_perfect_shot:bool = not _target_is_player_and_has_not_fired(best_opponent_data.opponent) and randf() > aim_error_chance

	var angle_deviation: float = 0.0 if is_perfect_shot else perfect_shot_angle + randf_range(-aim_deviation_degrees, aim_deviation_degrees)
	
	var angle := clampf(perfect_shot_angle + angle_deviation, _tank.min_angle, _tank.max_angle)
	
	print_debug("Brute AI(%s): best_opponent=%s; best_weapon=%d; perfect_shot_angle=%f; angle_deviation=%f" 
		% [tank.name, best_opponent_data.opponent.name, best_weapon, perfect_shot_angle, angle_deviation])

	delete_weapon_infos(weapon_infos)
	
	return TargetActionState.new(best_opponent_data.opponent, best_weapon, angle)
	
class TargetActionState extends AIState:
	var _opponent: TankController
	var _weapon:int 
	var _angle:float

	func _init(opponent: TankController, weapon: int, angle: float):
		self._opponent = opponent
		self._weapon = weapon
		self._angle = angle

	func execute(tank: Tank) -> TankActionResult:
		return TankActionResult.new(
			 tank.max_power,
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
		return { opponent = closest_direct_opponent, angle = closest_direct_angle }

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
