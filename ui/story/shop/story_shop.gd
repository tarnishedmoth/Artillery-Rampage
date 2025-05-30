extends Control


func _on_done_pressed() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
