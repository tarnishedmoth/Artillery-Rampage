class_name AIState extends RefCounted

func enter(): pass
func exit(): pass
func execute(tank: Tank) -> TankActionResult: return null

class NullState extends AIState:
	func execute(tank: Tank) -> TankActionResult:
		return TankActionResult.new()
