class_name NearsightBruteAIBehavior extends BruteAIBehavior

@export_group("Nearsight")
## Max fraction of playable area width to consider zero aim error
@export_range(0.0, 1.0, 0.01) var zero_error_distance_frac: float = 0.25

## Min fraction of playable area width to consider max aim error
@export_range(0.0, 1.0, 0.01) var max_error_distance_frac: float = 0.67

@export_group("Nearsight")
@export_range(0.0, 90.0, 1.0) var max_aim_error: float = 30.0

@export_group("Nearsight")
@export_range(0.0, 10.0, 0.1) var aim_error_dev: float = 2.0

@export_group("Nearsight")
@export_range(1.0, 10.0, 0.1) var error_dist_exp: float = 2.0

func _is_perfect_shot(opponent_data: Dictionary) -> bool:
	# Manually calculate the error
	return false
	
func get_aim_error(perfect_shot_angle: float, opponent_data: Dictionary) -> float:
	# Aim error increases with closer distance
	var distance: float = opponent_data.distance
	var angle_sgn: float = sign(perfect_shot_angle)
	
	var aim_error: float = max_aim_error * angle_sgn * get_error_fract(distance)
	if is_zero_approx(aim_error):
		return 0.0
	
	return aim_error + randf_range(0.0, aim_error_dev)

func get_error_fract(distance: float) -> float:
	var playable_x_extent: float = _get_playable_x_extent()
	var perfect_distance_threshold:float = zero_error_distance_frac * playable_x_extent
	if distance <= perfect_distance_threshold:
		return 0.0
	
	var max_error_distance_threshold: float = max_error_distance_frac * playable_x_extent
	if distance >= max_error_distance_threshold:
		return 1.0

	var distance_error_frac: float = (max_error_distance_threshold - distance) / (max_error_distance_threshold - perfect_distance_threshold)
	return pow(distance_error_frac, error_dist_exp)
	
