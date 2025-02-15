class_name AITankStateMachine extends Node

@export var behavior_type: Enums.AIType

var ai_behavior: AIBehavior
var active_state: AIState;

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

func _ready() -> void:
	ai_behavior = AITypes.new_ai_behavior(behavior_type)
	add_child(ai_behavior)
