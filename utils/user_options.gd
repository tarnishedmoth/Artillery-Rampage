extends Node

var keybinds:Dictionary[StringName,InputEvent] # action, keybind

var show_tooltips:bool = true
var show_hud:bool = true
var show_assist_trajectory_preview:bool = true

var volume_music:float = 0.8
var volume_sfx:float = 1.0
var volume_voice:float = 0.8

func _ready() -> void:
	enforce_options()

func enforce_options() -> void:
	audio_bus_check()
	apply_user_keybinds()
	#etc

func audio_bus_check() -> void:
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(volume_music))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(volume_sfx))

func apply_user_keybinds() -> void:
	var index:int = 0
	for action in get_all_keybinds():
		#change_keybind(action, keybinds[action])
		pass
		
		
func reset_all_keybinds_to_default() -> void:
	InputMap.load_from_project_settings()
	
func change_keybind(action, new_key) -> void:
	# Take an InputEvent and reassign it to a new key
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
