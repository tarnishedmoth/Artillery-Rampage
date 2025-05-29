## Singleton instance that orchestrates modifying the scene tree for story mode
extends Node

## Set sthe story mode level modifiers scene
## This will be kept empty while the system is being developed
## But will be set to "res://story/story_mode_level_modifiers.tscn"
## once the weapon unlock shop at end of level is ready that can be purchased with scrap
## Later can also use scrap to purchase a random mod bundle that can upgrade existing weapons
## These will also be rewarded at the end of a story win with possibly a free choice weapon as well
## Idea is that player will have 1/3 choices for upgrade at end of a win
## 1 will be a one time mod bundle, 1 will be a weapon that can also be purchased later, and 1 will be a passive upgrade like health
## The idea is for this to be a meaningful choice with an opportunity cost associated with it as the exact mod bundle may never appear again
## Maybe we can associate a score with it like "common, uncommon, rare, and legendary"
## Player can also use scrap to refill ammo on existing weapons and a discount if refilling all ammo (as opposed to doing it for each)
## Player can refill health at a personnel discount (50%) of losing it in a loss
@export
var story_mode_level_modifiers_scene:PackedScene

func _ready() -> void:
	# Only connect if enable the story mode level modifiers
	if not story_mode_level_modifiers_scene:
		return

	GameEvents.scene_switched.connect(_on_scene_switched)

func _on_scene_switched(new_scene: Node) -> void:
	# Skip if not in story mode
	if SceneManager.play_mode != SceneManager.PlayMode.STORY:
		return

	# Make sure this is a game level and not some other kind of UI screen
	var game_level: GameLevel = _get_game_level(new_scene)
	if not game_level:
		return
	
	print_debug("Applying story mode level modifiers to new_scene=%s" % [new_scene.scene_file_path])

	var story_mode_level_modifiers:Node = story_mode_level_modifiers_scene.instantiate()
	game_level.add_child(story_mode_level_modifiers)

func _get_game_level(scene: Node) -> GameLevel:
	var nodes:Array[Node] = [scene]

	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is GameLevel:
			return node
		nodes.append_array(node.get_children())
	
	return null
