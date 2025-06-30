extends Node2D

func _process(delta: float) -> void:
	get_parent().global_position = get_global_mouse_position()
