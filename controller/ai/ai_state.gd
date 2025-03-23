class_name AIState extends RefCounted

# Higher values are prioritized over lower ones
var priority: int = 0

func enter(): pass
func exit(): pass
func execute(_tank: Tank) -> TankActionResult: return null

class NullState extends AIState:
	func execute(_tank: Tank) -> TankActionResult:
		return TankActionResult.new()
