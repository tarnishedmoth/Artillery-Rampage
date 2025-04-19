class_name StorySaveUtils

static func story_save_exists() -> bool:
	var save:SaveState = SaveStateManager.save_state
	
	if not save or not save.state:
		return false
	var state : Dictionary[StringName, Dictionary] = save.state
	
	return state.has(StoryLevelState.SAVE_STATE_KEY)

static func set_story_level_index() -> void:
	var save:SaveState = SaveStateManager.save_state
	if not save or not save.state:
		return

	StoryLevelState.restore_story_level_state(save)
