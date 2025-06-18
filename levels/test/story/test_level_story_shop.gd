extends Node2D

## Change the scrap available for the shop. -1 means don't change the saved defaults
@export var scrap:int = -1

## Change the personnel available for the shop. -1 means don't change the saved defaults
@export var personnel:int = -1

func _ready() -> void:
	if not StorySaveUtils.story_save_exists():
		push_error("%s - No story save exists - start a new story and finish one level and then come back and test" % [name])
		return

	if scrap >= 0 or personnel >= 0:
		PlayerAttributes.scrap = maxi(scrap,0)
		PlayerAttributes.personnel = maxi(personnel, 1)
		PlayerAttributes.ignore_save_state()

	# Set up story precondition state
	# Copied from main_menu.gd _on_continue_story_pressed
	PlayerStateManager.enable = true
	SceneManager.play_mode = SceneManager.PlayMode.STORY

	# Now load the story shop scene
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryShop, 0.0)
