extends Node

var keybinds:Dictionary[StringName,Array] # action, InputEvents TODO

var show_tooltips:bool = true
var show_hud:bool = true
var show_assist_trajectory_preview:bool = true

var volume_music:float = 0.8
var volume_sfx:float = 1.0
var volume_speech:float = 1.0

func _ready() -> void:
	GameEvents.user_options_changed.connect(_on_options_applied)

	enforce_options()

func enforce_options() -> void:
	audio_bus_check()
	apply_user_keybinds()
	#etc

func audio_bus_check() -> void:
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var speech_bus = AudioServer.get_bus_index("Speech")
	
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(volume_music))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(volume_sfx))
	AudioServer.set_bus_volume_db(speech_bus, linear_to_db(volume_speech))

## TODO
func apply_user_keybinds() -> void:
	#var index:int = 0
	#for action in keybinds:
		#change_keybinds(action)
	pass
		
		
func reset_all_keybinds_to_default() -> void:
	InputMap.load_from_project_settings()
	
func change_keybind(action, new_key) -> void:
	# TODO make this save/loadable with keybinds dictionary
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_key)
	print_debug("New bind: ", action, get_glyphs(action))
	
## Not working
#func change_keybinds(action) -> void:
	#if action is not StringName: action = StringName(action)
	#
	#var iter:int = 0
	#if action in get_all_keybinds():
		#InputMap.action_erase_events(action)
		#for bind in keybinds[action]:
			#InputMap.action_add_event(action, bind)
			#iter+=1
	#print_debug("Assigned ", iter, " keybinds to ", action)
#
#func add_keybind(action, new_key) -> void:
	#if action is not StringName: action = StringName(action)
	#
	#if action in get_all_keybinds():
		#keybinds[action].append(new_key)
		#print_debug("Added key")
	#change_keybinds(action)
	#
#func remove_keybind(action, key) -> void:
	#if action is not StringName: action = StringName(action)
	#
	#if key in get_glyphs(action):
		#if keybinds.has(action):
			#if keybinds[action].has(key):
				#keybinds[action].erase(key)
		#print_debug("Removed key")
	#change_keybinds(action)
	
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

#region Savable
const SAVE_STATE_KEY:StringName = &"UserOptions"

func restore_from_save_state(save: SaveState) -> void:
	if not save.state.has(SAVE_STATE_KEY):
		return
	var state:Dictionary = save.state[SAVE_STATE_KEY]

	show_tooltips = state.show_tooltips
	show_hud = state.show_hud
	show_assist_trajectory_preview = state.show_assist_trajectory_preview
	
func update_save_state(save:SaveState) -> void:
	# Only save on explicit node trigger (see below)
	if save.context != SaveState.SaveContext.Node:
		return
	var state:Dictionary = save.state.get_or_add(SAVE_STATE_KEY, {})
	
	state.show_tooltips = show_tooltips
	state.show_hud = show_hud
	state.show_assist_trajectory_preview = show_assist_trajectory_preview
	
func _on_options_applied() -> void:
	# Explicitly save the options when they are applied
	SaveStateManager.save_node_state(self)
#endregion
