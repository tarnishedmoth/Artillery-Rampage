class_name StorySaveUtils

const RUN_KEY:StringName = &"Run"

static func story_save_exists(save:SaveState = null) -> bool:
	if not save:
		save = SaveStateManager.save_state
	
	if not save or not save.state:
		return false
	var state : Dictionary[StringName, Dictionary] = save.state
	
	var exists:bool = state.has(StoryLevelState.SAVE_STATE_KEY)
	return exists
	
static func get_story_save(save:SaveState = null, add_parent_if_not_exists:bool = false) -> Dictionary:
	if not story_save_exists(save):
		return {StoryLevelState.SAVE_STATE_KEY: {}} if add_parent_if_not_exists else {}
	
	if not save:
		save = SaveStateManager.save_state
	return save.state.get(StoryLevelState.SAVE_STATE_KEY)

static func set_story_level_index() -> void:
	var save:SaveState = SaveStateManager.save_state
	if not save or not save.state:
		return

	StoryLevelState.restore_story_level_state(save)

static func delete_story_save() -> void:
	SaveStateManager.clear_save_state_by_key(StoryLevelState.SAVE_STATE_KEY)

static func new_story_save() -> void:
	delete_story_save()
	var save:SaveState = SaveStateManager.save_state
	if save:
		save.state.set(StoryLevelState.SAVE_STATE_KEY, {RUN_KEY: 1})
		SaveStateManager.save_tree_state()
