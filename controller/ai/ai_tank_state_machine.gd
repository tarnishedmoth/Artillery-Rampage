class_name AITankStateMachine extends Node

class NullAIBehavior extends AIBehavior:
	func execute(tank: Tank) -> AIState: return AIState.NullState.new()

var ai_behavior: AIBehavior
var active_state: AIState
	
func _ready() -> void:
	ai_behavior = _find_existing_behavior()
	if ai_behavior:
		print_debug("%s - %s: Found existing behavior instance=%s", [get_parent().name, name, ai_behavior.name])
	else:
		push_error("%s - No AI Behavior found! AI will self-destruct by default!" % [get_parent().name])
		ai_behavior = NullAIBehavior.new()

func execute(tank: Tank) -> TankActionResult:
	var state = ai_behavior.execute(tank)
	if !is_instance_valid(state):
		# TODO: Maybe returning a null state is something we want to handle with a default?
		push_error("ai_behavior " + ai_behavior.name + " returned a null state!")
		return
	if(state != active_state):
		if is_instance_valid(active_state):
			active_state.exit()
		state.enter()
		active_state = state
	
	return active_state.execute(tank)

func change_behavior(type: Enums.AIBehaviorType) -> void:
	var new_behavior : AIBehavior = AITypes.new_ai_behavior(type)
	if not new_behavior:
		return
	if ai_behavior:
		remove_child(ai_behavior)
		ai_behavior.queue_free()
	
	ai_behavior = new_behavior
	add_child(new_behavior)
	
func _find_existing_behavior() -> AIBehavior:
	for child in get_children():
		if child is AIBehavior:
			return child
	return null
