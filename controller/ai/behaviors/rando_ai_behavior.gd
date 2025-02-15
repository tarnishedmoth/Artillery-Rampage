class_name RandoAIBehavior extends AIBehavior

var active_state: AIState;

func _ready() -> void:
	active_state = RandomActionState.new()

func execute(tank: Tank) -> AIState:
	return active_state
	
# Classic "Mr. Stupid" AI :) 	
class RandomActionState extends AIState:
	func execute(tank: Tank) -> TankActionResult:
		return TankActionResult.new(
			 randf_range(0, tank.max_power),
			 randf_range(tank.min_angle, tank.max_angle)
		)
