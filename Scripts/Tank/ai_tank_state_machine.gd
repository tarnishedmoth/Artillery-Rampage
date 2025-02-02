class_name AITankStateMachine extends Node

class TankActionResult:
	var power: float = 0
	var angle: float = 0
	# TODO: Select weapon
	
class AIState:
	func enter(): pass
	func exit(): pass
	func execute() -> TankActionResult: return null

class AttackState extends AIState:
	func enter(): pass
	func exit(): pass
	func execute() -> TankActionResult: return null
	
var active_state: AIState;

func execute(tank: Tank) -> TankActionResult:
	# TODO: Need to set a base ai personna behavior
	# The state machine state space is going to be somewhat driven by that
	var result = TankActionResult.new()
	result.angle = randf_range(tank.min_angle, tank.max_angle)
	result.power = randf_range(0, tank.max_power)
	
	return result
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
