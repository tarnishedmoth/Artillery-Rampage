class_name BruteAIBehavior extends AIBehavior

@export_group("Config")
@export_range(0.0, 1.0, 0.01) var aim_error_chance: float = 0.0

@export_group("Config")
@export_range(0.0, 60.0, 1.0) var aim_deviation_degrees: float = 15.0

@export_group("Config")
@export_flags("Gravity", "Wind") var forces_mask: int = Forces.Gravity

func _ready() -> void:
	pass

# TODO: Maybe don't need the tank parameter
func execute(_tank: Tank) -> AIState:
	super.execute(_tank)
	
	var best_opponent_data: Dictionary = _select_best_opponent()
	var best_weapon: int = _select_best_weapon(best_opponent_data.opponent)

	var perfect_shot_angle: float = best_opponent_data.angle
	var angle_deviation: float = 0 if randf() > aim_error_chance else perfect_shot_angle + randf_range(-aim_deviation_degrees, aim_deviation_degrees)
	
	var angle := clampf(perfect_shot_angle + angle_deviation, _tank.min_angle, _tank.max_angle)
	
	print_debug("Brute AI(%s): best_opponent=%s; best_weapon=%d; perfect_shot_angle=%f; angle_deviation=%f" 
		% [tank.name, best_opponent_data.opponent.name, best_weapon, perfect_shot_angle, angle_deviation])
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

	# If there is no direct shot opponent, then we will just return the closest opponent
	for opponent in opponents:
		var result: Dictionary = has_direct_shot_to(opponent, forces_mask)

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
	else:
		return { opponent = closest_opponent, angle = get_direct_aim_angle_to(closest_opponent) }

func _select_best_weapon(opponent: TankController) -> int:
	# TODO: Favor powerful weapons for opponents further away or when it is next to other opponents
	# Consider self splash damage if opponent too close
	# Use a scoring system (utility AI) to determine best weapon
	# Possibly the scoring system needs to influence both best opponent and best weapon
	# E.g. We select further opponents because there is a cluster further away and we have a nuke
	# There is an opponent right next to us but we don't want to shoot them as we expect to do more total damage
	# and threat of close opponent does not outweight that
	# Variables to take into account: distance to target, threat of target, weapon self damage, total expected damage
	return randi_range(0, tank.weapons.size() - 1)
