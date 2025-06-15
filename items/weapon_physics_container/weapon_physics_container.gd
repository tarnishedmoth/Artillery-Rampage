class_name WeaponPhysicsContainer

var name: String:
	get: return _get_name()

var last_recorded_linear_velocity: Vector2:
	get: return _get_last_recorded_linear_velocity()

var angular_velocity: float:
	get: return _get_angular_velocity()

func _get_name() -> String:
	return needs_override()

func _get_last_recorded_linear_velocity() -> Vector2:
	return needs_override()

func _get_angular_velocity() -> float:
	return needs_override()

func get_destructible_component() -> CollisionPolygon2D:
	return needs_override()
	
func needs_override():
	push_error('Abstract class method used. Subclasses should override this method.')
