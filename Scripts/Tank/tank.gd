class_name Tank extends Node2D

@export var min_angle:float = -90
@export var max_angle:float = 90


@onready var turret = $TankBody/TankTurret

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func aim_at(angle_rads: float) -> void:
	turret.rotation = clampf(angle_rads, deg_to_rad(min_angle), deg_to_rad(max_angle))

func aim_delta(angle_rads_delta: float) -> void:
	aim_at(turret.rotation + angle_rads_delta)
	
func get_turret_rotation() -> float:
	return turret.rotation
	
func shoot() -> void:
	# TODO: Spawn current weapon projectile 
	pass
