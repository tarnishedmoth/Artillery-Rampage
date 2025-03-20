class_name DestructibleUtils

class DamageConfiguration:
	var damage_scale_failure_reduction_step: float = 10.0
	var min_damage_shape_offset: float = 0
	var max_damage_shape_offset: float = 1

static func get_projectile_poly_global( projectile_poly: CollisionPolygon2D, poly_scale: Vector2, )
