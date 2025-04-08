extends Node

var show_tooltips:bool = true
var show_hud:bool = true
var show_assist_trajectory_preview:bool = false

var volume_music:float = 0.8
var volume_sfx:float = 1.0
var volume_voice:float = 0.8

# keybinds
func change_keybind_to(bind, new_key) -> void:
	pass
	
func get_all_keybinds() -> Array[StringName]: ## Returns InputMap.get_actions()
	var actions: Array[StringName]
	for action in InputMap.get_actions():
		if action.begins_with("ui"):
			continue # Ignore built-ins
		else:
			actions.append(action)
		
	return actions
	
func get_glyphs(action: StringName) -> Array[String]:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var texts: Array[String]
	for event in events:
		texts.append(event.as_text())
	
	return texts

func reset_all_keybinds_to_default() -> void:
	InputMap.load_from_project_settings()
