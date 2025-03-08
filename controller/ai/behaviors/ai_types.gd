extends Node

var _ai_behaviors: Dictionary = {}

# Define additional AIBehavior derived scripts here
# If defaults should be configurable then wrap in a scene
const RandoAiBehavior = preload("res://controller/ai/behaviors/rando_ai_behavior.gd")
const BruteAiBehavior = preload("res://controller/ai/behaviors/brute_ai_behavior.tscn")

func _ready():
	# Add the behavior type mappings to the dictionary
	_ai_behaviors[Enums.AIType.Rando] = RandoAiBehavior
	_ai_behaviors[Enums.AIType.Brute] = BruteAiBehavior
	
func new_ai_behavior(type: Enums.AIType) -> AIBehavior:
	var behavior = _ai_behaviors.get(type)
	if !is_instance_valid(behavior):
		push_error("No behavior found for type=" + str(type))
		return null
	var as_packed_scene := behavior as PackedScene
	if as_packed_scene:
		print_debug("Creating new default behavior instance from type=%s using packed scene=%s" % [type, as_packed_scene])
		return as_packed_scene.instantiate()
		
	# Create a new node from the script
	print_debug("Creating new default behavior instance from type=%s using script %s" % [type, behavior])
	
	return behavior.new()

func new_ai_behavior_from_scene(scene: PackedScene) -> AIBehavior:
	var behavior = scene.instantiate()
	if behavior is AIBehavior:
		print_debug("Returning new AIBehavior instance=%s from scene=%s", [behavior, scene])
	else:
		push_error("Scene %s is not an AIBehavior!" % [scene])
	return behavior
