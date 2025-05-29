extends Control


func _on_easy_pressed() -> void:
	_start_story(Difficulty.DifficultyLevel.EASY)

func _on_normal_pressed() -> void:
	_start_story(Difficulty.DifficultyLevel.NORMAL)

func _on_hard_pressed() -> void:
	_start_story(Difficulty.DifficultyLevel.HARD)

func _start_story(difficulty: Difficulty.DifficultyLevel) -> void:
	UserOptions.difficulty = difficulty
	await SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
