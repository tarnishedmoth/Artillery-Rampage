extends Node

var is_restarting: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func quit() -> void:
	get_tree().quit()
	
func restart_level(delay: float = 1.0) -> void:
	if is_restarting:
		return
	
	# Avoid two events causing a restart in the same game (e.g. player dies and leaves 1 player remaining)
	is_restarting = true
	await get_tree().create_timer(delay).timeout
	
	is_restarting = false
	# Restart the game 
	get_tree().reload_current_scene()
	
func switch_scene(scene: PackedScene) -> void:
	get_tree().change_scene_to_packed(scene)
	
func switch_scene_file(scene: NodePath) -> void:
	get_tree().change_scene_to_file(scene)
