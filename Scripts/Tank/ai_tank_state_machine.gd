class_name AITankStateMachine extends Node

class TankActionResult:
	var power: float
	
	# Target angle in rads
	var angle: float
	# TODO: Select weapon
	
	func _init(power: float = 0, angle: float = 0):
		self.power = power
		self.angle = deg_to_rad(angle)
	
class AIState:
	func enter(): pass
	func exit(): pass
	func execute(tank: Tank) -> TankActionResult: return null

class AttackState extends AIState:
	func enter(): pass
	func exit(): pass
	func execute(tank: Tank) -> TankActionResult: return null
	

# Classic "Mr. Stupid" AI :) 	
class RandomActionState extends AIState:
	func execute(tank: Tank) -> TankActionResult:
		return TankActionResult.new(
			 randf_range(0, tank.max_power),
			 randf_range(tank.min_angle, tank.max_angle)
		)
			
	
var active_state: AIState;

func execute(tank: Tank) -> TankActionResult:
	# TODO: Need to set a base ai personna behavior
	# The state machine state space is going to be somewhat driven by that
	return active_state.execute(tank)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	active_state = RandomActionState.new()
	active_state.enter()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
