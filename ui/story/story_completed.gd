extends Control

@onready var run_header_label:Label = %RunHeaderLabel

func _ready() -> void:
	var story_level_state:StoryLevelState = get_tree().get_first_node_in_group(Groups.StoryLevelState) as StoryLevelState
	var run_count_str:String = ""
	if story_level_state:
		var run_count:int = story_level_state.run_count
		run_header_label.text = run_header_label.text.replace("%RUN%", str(run_count))
	else:
		push_error("%s: Could not find StoryLevelState node in tree" % name)

func _on_yes_pressed() -> void:
	print_debug("%s: Selected new run" % name)
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)

func _on_no_pressed() -> void:
	print_debug("%s: Selected to end story" % name)
	StorySaveUtils.delete_story_save()
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu)
