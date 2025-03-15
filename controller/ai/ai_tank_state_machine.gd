class_name AITankStateMachine extends Node

class NullAIBehavior extends AIBehavior:
	func execute(_tank: Tank) -> AIState: return AIState.NullState.new()

var ai_behaviors: Array[AIBehavior] = []
var active_state: AIState

var priority_mappings: Dictionary = {}
	
func _ready() -> void:
	ai_behaviors = _find_existing_behaviors()
	if ai_behaviors:
		print_debug("%s - %s: Found existing behavior instances=%s", [get_parent().name, name, ",".join(ai_behaviors.map(func(x): return x.name))])
	else:
		push_error("%s - No AI Behaviors found! AI will self-destruct by default!" % [get_parent().name])
		ai_behaviors = [NullAIBehavior.new()]

func execute(tank: Tank) -> TankActionResult:
	var state: AIState = _get_best_state(tank)
	if !is_instance_valid(state):
		push_error("%s - Could not determine an AI state!" % [get_parent().name])
		if !is_instance_valid(active_state):
			active_state = AIState.NullState.new()
	elif(state != active_state):
		if is_instance_valid(active_state):
			active_state.exit()
		state.enter()
		active_state = state
	
	return active_state.execute(tank)

func change_default_priority(type: Enums.AIBehaviorType, priority: int) -> void:
	for behavior in ai_behaviors:
		if behavior.behavior_type == type:
			priority_mappings[behavior] = behavior.default_priority
			behavior.default_priority = priority
		elif priority_mappings.has(behavior):
			behavior.default_priority = priority_mappings[behavior]

func _get_best_state(tank: Tank) -> AIState:
	var best_state: AIState = null
	var best_priority: int = -1
	for behavior in ai_behaviors:
		var state: AIState = behavior.execute(tank)
		if state and state.priority > best_priority:
			best_priority = state.priority
			best_state = state
	return best_state

func change_behavior(type: Enums.AIBehaviorType) -> void:
	var new_behavior : AIBehavior = AITypes.new_ai_behavior(type)
	if not new_behavior:
		return
		
	for behavior in ai_behaviors:
		remove_child(behavior)
		behavior.queue_free()
	ai_behaviors.clear()
	priority_mappings.clear()

	ai_behaviors.push_back(new_behavior)
	add_child(new_behavior)
	
func _find_existing_behaviors() -> Array[AIBehavior]:
	var behaviors: Array[AIBehavior] = []
	for child in get_children():
		if child is AIBehavior:
			behaviors.push_back(child)
	return behaviors
