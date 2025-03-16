class_name NearsightAIErrorCalculation extends Node

@export_group("Nearsight")
## Max fraction of playable area width to consider zero aim error
@export_range(0.0, 1.0, 0.01) var zero_error_distance_frac: float = 0.25

@export_group("Nearsight")
## Min fraction of playable area width to consider max aim error
@export_range(0.0, 1.0, 0.01) var max_error_distance_frac: float = 0.67

@export_group("Nearsight")
@export_range(1.0, 10.0, 0.1) var error_dist_exp: float = 2.0

func get_error_fract(playable_x_extent: float, distance: float) -> float:
	var perfect_distance_threshold:float = zero_error_distance_frac * playable_x_extent
	if distance <= perfect_distance_threshold:
		return 0.0
	
	var max_error_distance_threshold: float = max_error_distance_frac * playable_x_extent
	if distance >= max_error_distance_threshold:
		return 1.0

	var distance_error_frac: float = (max_error_distance_threshold - distance) / (max_error_distance_threshold - perfect_distance_threshold)
	return pow(distance_error_frac, error_dist_exp)
