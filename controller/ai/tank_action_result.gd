class_name TankActionResult extends RefCounted

var power: float

# Target angle in rads
var angle: float

var weapon_index: int

func _init(power: float = 0, angle: float = 0, weapon_index: int = 0):
	self.power = power
	self.angle = deg_to_rad(angle)
	self.weapon_index = weapon_index
