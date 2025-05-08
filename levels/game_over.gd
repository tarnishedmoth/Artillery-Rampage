extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _on_retry_pressed():
	# TODO: Code duplication with main menu - move this into scene manager
	PlayerStateManager.enable = true
	SaveStateManager.add_state_flag(SceneManager.new_story_selected)
	SceneManager.play_mode = SceneManager.PlayMode.STORY

	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryStart)


func _on_quit_pressed():
	# TODO: Maybe do this from round summary
	SaveStateManager.clear_save_state_by_key(StoryLevelState.SAVE_STATE_KEY)
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu)
