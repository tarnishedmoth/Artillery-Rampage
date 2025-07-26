class_name WeaponScorer extends Node

func handles_weapon(_weapon: Weapon, _projectile: Node2D) -> bool:
	return false

func compute_score(_tank: Tank, _weapon: Weapon, _projectile: Node2D, _target_distance:float, _opponents: Array[TankController], _comparison_result:int) -> float:
	push_error("Not implemneted")
	return 0.0
