class_name AITankStateMachine extends Node


@export_group("Config")
@export_category("Default")
## Uses a default behavior node for that type
@export var behavior_type: Enums.AIType 

# Alternative way if want to customize the AI behavior for a specific AI type
# E.g. a brute AI that has a higher miss rate that we want to configure at design time
## 
@export_group("Config")
@export_category("Custom")
## Specify a custom scene for the behavior. Useful if need to customize the default behavior properties.
## Used in place of the behavior_type. A third option is to add a child node of a behavior type and this will be used in place of the other options.
@export var ai_behavior_scene: PackedScene

var ai_behavior: AIBehavior
var active_state: AIState

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
	ai_behavior = _find_existing_behavior()
	if ai_behavior:
		print_debug("%s - %s: Found existing behavior instance=%s", [get_parent().name, name, ai_behavior.name])
	else:
		ai_behavior = AITypes.new_ai_behavior_from_scene(ai_behavior_scene) if ai_behavior_scene else AITypes.new_ai_behavior(behavior_type)
		add_child(ai_behavior)

func _find_existing_behavior() -> AIBehavior:
	for child in get_children():
		if child is AIBehavior:
			return child
	return null
