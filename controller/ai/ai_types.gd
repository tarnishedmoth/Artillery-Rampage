extends Node

var _ai_scenes: Dictionary = {}

# Idea is to return a specific AI unit that is useful given certain conditions - e.g. no wind, high wind, etc

const RandoAi: PackedScene = preload("res://controller/ai/variations/ai_tank_rando.tscn")
const BruteAi: PackedScene = preload("res://controller/ai/variations/ai_tank_brute.tscn")
const LobberAi: PackedScene = preload("res://controller/ai/variations/ai_tank_lobber.tscn")


var _ai_behaviors: Dictionary = {}

# Define additional AIBehavior derived scripts here
# If defaults should be configurable then wrap in a scene
const RandoAiBehavior = preload("res://controller/ai/behaviors/rando_ai_behavior.tscn")
const BruteAiBehavior = preload("res://controller/ai/behaviors/brute_ai_behavior.tscn")
const LobberAibehavior = preload("res://controller/ai/behaviors/lobber_ai_behavior.tscn")

func _ready():
	# Add the AITank scene mappings to the dictionary
	_ai_scenes[Enums.AIType.Rando] = RandoAi
	_ai_scenes[Enums.AIType.Brute] = BruteAi
	_ai_scenes[Enums.AIType.Lobber] = LobberAi
	
	_ai_behaviors[Enums.AIBehaviorType.Rando] = RandoAiBehavior
	_ai_behaviors[Enums.AIBehaviorType.Brute] = BruteAiBehavior
	_ai_behaviors[Enums.AIBehaviorType.Lobber] = LobberAibehavior
	
# Can add additional optional parameters here that could influence the specific scene returned
func new_ai_tank(type: Enums.AIType) -> AITank:
	var scene = _ai_scenes.get(type)
	if !is_instance_valid(scene):
		push_error("No AITank scene found for type=" + str(type))
		return null
	var as_packed_scene := scene as PackedScene
	if as_packed_scene:
		return new_ai_tank_from_scene(as_packed_scene)
	push_error("Scene %s is not a PackedScene!" % [scene])

	return null

func new_ai_tank_from_scene(scene: PackedScene) -> AITank:
	var instance = scene.instantiate()
	if instance is AITank:
		print_debug("Returning new AITank instance=%s from scene=%s", [instance, scene])
	else:
		push_error("Scene %s is not an AITank!" % [scene])
	return instance

func new_ai_behavior(type: Enums.AIBehaviorType) -> AIBehavior:
	var behavior = _ai_behaviors.get(type)
	if !is_instance_valid(behavior):
		push_error("No behavior found for type=" + str(type))
		return null
	var as_packed_scene := behavior as PackedScene
	if as_packed_scene:
		return new_ai_behavior_from_scene(as_packed_scene)
		
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
