class_name AIState extends RefCounted

# Higher values are prioritized over lower ones
var priority: int = 0

func enter(): pass
func exit(): pass
func execute(_tank: Tank) -> TankActionResult: return null

class NullState extends AIState:
	func execute(_tank: Tank) -> TankActionResult:
		return TankActionResult.new()

class MaxPowerState extends AIState:
	var power: float
	var angle: float
	var weapon_index: int

	func _init(_tank:Tank, _weapon_index: int):
		power = _tank.max_power
		angle = 45.0
		weapon_index = _weapon_index

	func execute(_tank: Tank) -> TankActionResult:
		return TankActionResult.new(power, angle, weapon_index)
