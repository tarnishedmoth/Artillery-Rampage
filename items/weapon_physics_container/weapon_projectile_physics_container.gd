class_name WeaponProjectilePhysicsContainer extends WeaponPhysicsContainer

var containedObject: WeaponProjectile

func _init(projectile: WeaponProjectile):
	containedObject = projectile

func _get_name() -> String:
	return containedObject.name

func _get_last_recorded_linear_velocity() -> Vector2:
	return containedObject.last_recorded_linear_velocity

func _get_angular_velocity() -> float:
	return containedObject.angular_velocity

func get_destructible_component() -> CollisionPolygon2D:
	return containedObject.get_destructible_component()
