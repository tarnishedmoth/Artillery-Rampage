extends Control

@onready var run_header_label:Label = %RunHeaderLabel
@onready var yes_button:Button = %Yes
@onready var no_button:Button = %No
@onready var confirmation_dialog = %ARConfirmationDialog

func _ready() -> void:
	var story_level_state:StoryLevelState = get_tree().get_first_node_in_group(Groups.StoryLevelState) as StoryLevelState
	if story_level_state:
		var run_count:int = story_level_state.run_count
		run_header_label.text = run_header_label.text.replace("%RUN%", str(run_count))
	else:
		push_error("%s: Could not find StoryLevelState node in tree" % name)

func _on_yes_pressed() -> void:
	print_debug("%s: Selected new run" % name)
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
	
	_disable_buttons()

func _on_no_pressed() -> void:
	confirmation_dialog.set_text("Are you sure you want to end your run?\n This will delete your current save.")
	confirmation_dialog.popup_centered()

func _on_no_confirmed() -> void:
	_on_no_action()

func _on_no_action() -> void:
	print_debug("%s: Selected to end story" % name)

	StorySaveUtils.delete_story_save()
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu)
	
	_disable_buttons()

func _disable_buttons() -> void:
	yes_button.disabled = true
	no_button.disabled = true
