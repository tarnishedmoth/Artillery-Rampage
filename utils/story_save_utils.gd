class_name StorySaveUtils

static func story_save_exists() -> bool:
	var save:SaveState = SaveStateManager.save_state
	
	if not save or not save.state:
		return false
	var state : Dictionary[StringName, Dictionary] = save.state
	
	var exists:bool = state.has(StoryLevelState.SAVE_STATE_KEY)
	return exists
	
static func get_story_save() -> Dictionary:
	if not story_save_exists():
		return {}
	
	return SaveStateManager.save_state.state.get(StoryLevelState.SAVE_STATE_KEY)

static func set_story_level_index() -> void:
	var save:SaveState = SaveStateManager.save_state
	if not save or not save.state:
		return

	StoryLevelState.restore_story_level_state(save)
