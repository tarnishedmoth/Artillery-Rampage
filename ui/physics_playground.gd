extends Node2D

@export var spawnables:Array[PackedScene]

func _input(event: InputEvent) -> void:
	if event.is_action_type():
		spawn()
		
func spawn() -> void:
	var spawnable:PackedScene = spawnables.pick_random()
	var instance:Node2D = spawnable.instantiate()
	instance.global_position = get_global_mouse_position()
	instance.global_rotation = randf_range(-TAU, TAU)
	add_child(instance)
