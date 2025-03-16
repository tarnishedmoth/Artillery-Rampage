class_name SniperAIErrorCalculation extends Node

@export_group("Sniper")
## Min fraction of playable area width to consider zero aim error
@export_range(0.0, 1.0, 0.01) var zero_error_distance_frac: float = 0.5

@export_group("Sniper")
## Max target distance
@export_range(100.0, 1.0, 0.01) var max_target_distance: float = 500.0

@export_group("Sniper")
@export_range(1.0, 10.0, 0.1) var error_dist_exp: float = 2.0

func get_error_fract(playable_x_extent: float, distance: float) -> float:
	var perfect_distance_threshold:float = zero_error_distance_frac * playable_x_extent
	if distance >= perfect_distance_threshold:
		return 0.0
	
	var distance_error_frac: float = 1.0 - distance / perfect_distance_threshold
	return pow(distance_error_frac, error_dist_exp)
