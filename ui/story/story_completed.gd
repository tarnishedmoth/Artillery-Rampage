extends Control

@onready var run_header_label:Label = %RunHeaderLabel
@onready var yes_button:Button = %Yes
@onready var no_button:Button = %No
@onready var confirmation_dialog:ConfirmationDialog = %ARConfirmationDialog
@onready var victory_texture:TextureRect = %VictoryImage

func _ready() -> void:
	# Set to player color
	# TODO: This can be swapped out for a better image. By default showing the player tank as victorious
	victory_texture.modulate = Color(0xab/256.0, 0xff/256.0, 0x1a/256.0).darkened(0.3)
	
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
