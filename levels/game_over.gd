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
	# FIXME: Need to clear saved state for story at this point as out of personnel
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu)
