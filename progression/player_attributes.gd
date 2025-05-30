extends Node

@export var player_attribute_defaults: PlayerAttributeDefaults

## Related to lives though can expend to go out to retrieve items via the personnel copter system
var personnel: int:
	set(value):
		_dirty = _dirty || value != personnel
		personnel = value
	get:
		return personnel

## Used for item upgrade unlocks and also new tanks
## May also find a bonus item in level or at the end
var scrap:int:
	set(value):
		_dirty = _dirty || value != scrap
		scrap = value
	get:
		return scrap

var _dirty:bool = false

## Used for debugging to avoid reading or writing save state
func ignore_save_state() -> void:
	if not OS.is_debug_build():
		push_error("ignore_save_state() should only be used in debug builds")
		return
	
	print_debug("ignore_save_state() called, will not save or restore player attributes")
	remove_from_group(Groups.Savable)

func _ready() -> void:
	personnel = player_attribute_defaults.personnel
	scrap = 0
	_dirty = false
	
#region Savable

const SAVE_STATE_KEY:StringName = &"PlayerAttrs"

func restore_from_save_state(save: SaveState) -> void:
	if SceneManager.play_mode != SceneManager.PlayMode.STORY:
		return
	
	if save and save.state and SaveStateManager.consume_state_flag(SceneManager.new_story_selected, SAVE_STATE_KEY):
		save.state.erase(SAVE_STATE_KEY)
		
		personnel = player_attribute_defaults.personnel
		scrap = 0
		_dirty = false
		return

	if save and save.state and save.state.has(SAVE_STATE_KEY):
		var serialized_player_state: Dictionary = save.state[SAVE_STATE_KEY]

		personnel = serialized_player_state.personnel if serialized_player_state.has("personnel") else player_attribute_defaults.personnel
		scrap = serialized_player_state.scrap if serialized_player_state.has("scrap") else 0
		_dirty = false
		print_debug("restore_from_save_state: personnel=%d; scrap=%d" % [personnel, scrap])


func update_save_state(save:SaveState) -> void:
	if SceneManager.play_mode != SceneManager.PlayMode.STORY:
		return

	# Since this is a singleton, this function actually gets called before the state is loaded since SceneManager.play_mode is set to story in main menu
	if not _dirty or not save or not save.state:
		return

	var state:Dictionary = save.state.get_or_add(SAVE_STATE_KEY, {})

	state.personnel = personnel
	state.scrap = scrap
	_dirty = false
	
	print_debug("update_save_state: personnel=%d; scrap=%d" % [personnel, scrap])

#endregion
