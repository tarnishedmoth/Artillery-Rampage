extends Node

var _ai_behaviors: Dictionary = {}

# Define additional AIBehavior derived scripts here
const RandoAiBehavior = preload("res://controller/ai/behaviors/rando_ai_behavior.gd")
const BruteAiBehavior = preload("res://controller/ai/behaviors/brute_ai_behavior.gd")

func _ready():
	# Add the behavior type mappings to the dictionary
	_ai_behaviors[Enums.AIType.Rando] = RandoAiBehavior
	_ai_behaviors[Enums.AIType.Brute] = BruteAiBehavior
	
func new_ai_behavior(type: Enums.AIType) -> AIBehavior:
	var behavior = _ai_behaviors.get(type)
	if !is_instance_valid(behavior):
		push_error("No behavior found for type=" + str(type))
		return null
	return behavior.new()
