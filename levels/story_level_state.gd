class_name StoryLevelState extends Node

var _last_completed_level:int = -1
var _game_level:GameLevel

func _ready() -> void:
	_game_level = get_parent() as GameLevel
	if not _game_level:
		push_error("Parent=%s is not a GameLevel" % [get_parent().name if get_parent() else &"NULL"])
		return
		
	GameEvents.round_ended.connect(_on_round_ended)
	
func _on_round_ended() -> void:
	# TODO: This is kind of hacky but "won" is set in this signal in RoundStatTracker so there could be an ordering issue
	var player_won:bool = not RoundStatTracker.round_data.died
	print_debug("On Round ended: Player won=%s" % player_won)
	
	# Only increment level if won.
	# SceneManager.next_level increments so "current_level_index" is actually the next level here
	if player_won:
		_last_completed_level = SceneManager._current_level_index
		print_debug("last_completed_level=%d" [_last_completed_level])
		# TODO: This can increment beyond the end which will invalidate the story state
	
#region Savable
const SAVE_STATE_KEY:StringName = &"Story"
const _LEVEL_KEY:StringName = &"Level"

func restore_from_save_state(save: SaveState) -> void:
	if save and save.state and SaveStateManager.consume_state_flag(SceneManager.new_story_selected, SAVE_STATE_KEY):
		save.state.erase(SAVE_STATE_KEY)
		return
		
	var level:int = restore_story_level_state(save)
	if level != -1:
		_last_completed_level = level
		print_debug("last_completed_level=%d" [_last_completed_level])

func update_save_state(save:SaveState) -> void:
	if not save or not save.state:
		return
	
	if _last_completed_level >= 0:
		var state:Dictionary = save.state.get_or_add(SAVE_STATE_KEY, {})
		state[_LEVEL_KEY] = _last_completed_level
		print_debug("set save state last completed level=%d" [_last_completed_level])
	
static func restore_story_level_state(save: SaveState) -> int:
	if not save or not save.state:
		return -1
	
	if not save.state.has(SAVE_STATE_KEY):
		print_debug("No existing story level state found")
		return -1
	
	var state:Dictionary = save.state[SAVE_STATE_KEY]

	var last_level:int = state.get(_LEVEL_KEY, 0)
	print_debug("set story level index=%d" [last_level])
	SceneManager.set_story_level_index(last_level)
	
	return last_level
	
#endregion
