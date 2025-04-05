extends Node

var show_tooltips:bool = true
var show_hud:bool = true

var volume_music:float = 0.8
var volume_sfx:float = 1.0
var volume_voice:float = 0.8

# keybinds
func change_keybind_to(bind, new_key) -> void:
	pass
	
func get_all_keybinds() -> Array[StringName]:
	return InputMap.get_actions()

func reset_all_keybinds_to_default() -> void:
	InputMap.load_from_project_settings()
