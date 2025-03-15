class_name TankActionResult extends RefCounted

var power: float

# Target angle in rads
var angle: float

var weapon_index: int

func _init(set_power: float = 0, set_angle: float = 0, set_weapon_index: int = 0):
	self.power = set_power
	self.angle = deg_to_rad(set_angle)
	self.weapon_index = set_weapon_index
