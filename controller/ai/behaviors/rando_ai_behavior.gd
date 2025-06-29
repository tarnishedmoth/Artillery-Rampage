class_name RandoAIBehavior extends AIBehavior

@export_group("Config")
@export_range(0.0, 1.0, 0.05) var min_power_pct: float = 0.25

var active_state: AIState

func _ready() -> void:
	super._ready()
	
	behavior_type = Enums.AIBehaviorType.Rando
	active_state = RandomActionState.new(self)

func execute(_tank: Tank) -> AIState:
	super.execute(_tank)
	return active_state
	
# Classic "Mr. Stupid" AI :) 	
class RandomActionState extends AIState:
	var parent: RandoAIBehavior
	
	func _init(_parent: RandoAIBehavior):
		parent = _parent
		
	func execute(tank: Tank) -> TankActionResult:
		return TankActionResult.new(
			 randf_range(tank.max_power * parent.min_power_pct, tank.max_power),
			 randf_range(tank.min_angle, tank.max_angle),
			 randi_range(0, tank.weapons.size() - 1)
		)
