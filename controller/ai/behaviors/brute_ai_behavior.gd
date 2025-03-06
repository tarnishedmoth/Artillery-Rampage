class_name BruteAIBehavior extends AIBehavior

var active_state: AIState;

func _ready() -> void:
	active_state = RandomActionState.new()

func execute(tank: Tank) -> AIState:
	return active_state
	
# TODO: Replace with actual behavior state
# Select nearest opponent where we have a direct line of sight that is viable and aim power 100% at it
# Select an appropriate weapon - if opponent is too close then don't use Kilo Nuke or select a further opponent
class RandomActionState extends AIState:
	func execute(tank: Tank) -> TankActionResult:
		return TankActionResult.new(
			 tank.max_power,
			 randf_range(tank.min_angle, tank.max_angle),
			 randi_range(0, tank.weapons.size() - 1)
		)
