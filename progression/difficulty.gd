extends Node

enum DifficultyLevel
{
	EASY,
	NORMAL,
	HARD
}

@export var story_difficulty:DifficultyLevel = DifficultyLevel.HARD
@export var default_play_difficulty:DifficultyLevel = DifficultyLevel.HARD

## The current difficulty depending on the play mode
var current_difficulty:DifficultyLevel:
	get:
		return story_difficulty if SceneManager.play_mode == SceneManager.PlayMode.STORY else default_play_difficulty
	set(value):
		var old_value:DifficultyLevel
		if SceneManager.play_mode == SceneManager.PlayMode.STORY:
			old_value = story_difficulty
			story_difficulty = value
		else:
			old_value = default_play_difficulty
			default_play_difficulty = value
		
		if old_value != value:
			GameEvents.difficulty_changed.emit(value, old_value)
			
#region Savable

const SAVE_STATE_KEY:StringName = &"Difficulty"

func restore_from_save_state(save: SaveState) -> void:
	var story_save:Dictionary = StorySaveUtils.get_story_save()
	if story_save and story_save.has(SAVE_STATE_KEY):
		story_difficulty = story_save[SAVE_STATE_KEY]
		print_debug("%s: Restoring story difficulty to %s" % [name, str(story_difficulty)])
		
	if save.state.has(UserOptions.SAVE_STATE_KEY):
		var options_data:Dictionary = save.state.get(UserOptions.SAVE_STATE_KEY)
		if options_data.has(SAVE_STATE_KEY):
			default_play_difficulty = options_data[SAVE_STATE_KEY]
			print_debug("%s: Restoring default difficulty to %s" % [name, str(default_play_difficulty)])

func update_save_state(save:SaveState) -> void:
	if SceneManager.play_mode == SceneManager.PlayMode.STORY:
		var story_save:Dictionary = StorySaveUtils.get_story_save()
		if story_save:
			story_save[SAVE_STATE_KEY] = story_difficulty
			print_debug("%s: Saving story difficulty as %s" % [name, str(story_difficulty)])
	elif save.state.has(UserOptions.SAVE_STATE_KEY):
		save.state[UserOptions.SAVE_STATE_KEY][SAVE_STATE_KEY] = default_play_difficulty
		print_debug("%s: Saving default difficulty as %s" % [name, str(default_play_difficulty)])

#endregion
