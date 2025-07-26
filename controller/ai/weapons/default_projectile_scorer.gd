class_name DefaultProjectileScorer extends WeaponScorer

func handles_weapon(_weapon: Weapon, projectile: Node2D) -> bool:
	return projectile is WeaponProjectile

func compute_score(_tank: Tank, weapon: Weapon, in_projectile: Node2D, target_distance:float, _opponents: Array[TankController], _comparison_result:int) -> float:
	var projectile: WeaponProjectile = in_projectile as WeaponProjectile
	if not projectile or target_distance <= projectile.max_falloff_distance:
		# 0 signifies a netural result so won't be picked as best or worst
		return 0.0

	var count_multiplier: float = weapon.number_of_scenes_to_spawn
	if weapon.always_shoot_for_duration > 0:
		count_multiplier *= weapon.always_shoot_for_duration * weapon.fire_rate
	else:
		count_multiplier *= weapon.ammo_used_per_shot
	var score: float = projectile.max_damage * projectile.max_damage * projectile.min_falloff_distance * projectile.max_falloff_distance * count_multiplier

	return score
