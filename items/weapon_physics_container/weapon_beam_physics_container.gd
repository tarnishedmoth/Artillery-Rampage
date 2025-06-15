class_name WeaponBeamPhysicsContainer extends WeaponPhysicsContainer

var containedObject: WeaponNonPhysicalBeam

func _init(beam: WeaponNonPhysicalBeam):
	containedObject = beam

func _get_name() -> String:
	return containedObject.name

func _get_last_recorded_linear_velocity() -> Vector2:
	# Do we need the last_recorded_linear_velocity on non-projectile weapons?
	return Vector2(0, 0)

func _get_angular_velocity() -> float:
	# Do we need the angular_velocity on non-projectile weapons?
	return 0

func get_destructible_component() -> CollisionPolygon2D:
	return containedObject.get_destructible_component()
