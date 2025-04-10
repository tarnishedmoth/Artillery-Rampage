extends Node2D

@onready var debug_target: Node2D = %DebugTarget

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		$Turret.shoot()

func _process(delta: float) -> void:
	debug_target.global_position = get_global_mouse_position()
