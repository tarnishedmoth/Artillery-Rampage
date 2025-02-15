class_name TankActionResult extends RefCounted

var power: float

# Target angle in rads
var angle: float
# TODO: Select weapon

func _init(power: float = 0, angle: float = 0):
	self.power = power
	self.angle = deg_to_rad(angle)
