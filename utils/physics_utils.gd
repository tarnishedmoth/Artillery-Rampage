extends Node

var _default_gravity:Vector2

func _ready() -> void:
	_default_gravity = _get_default_gravity()
		
func get_gravity_vector(body: RigidBody2D = null) -> Vector2:
	if !body:
		return _default_gravity
	
	return body.gravity_scale * _default_gravity

func _get_default_gravity() -> Vector2:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity")) * Vector2(ProjectSettings.get_setting("physics/2d/default_gravity_vector"))
