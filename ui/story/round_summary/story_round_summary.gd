class_name StoryRoundSummary extends Control


func _on_next_pressed() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
