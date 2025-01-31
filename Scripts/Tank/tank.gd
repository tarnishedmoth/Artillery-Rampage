class_name Tank extends Node2D

@export var min_angle:float = -90
@export var max_angle:float = 90

@onready var turret = $TankBody/TankTurret
@onready var weapon_fire_location = $TankBody/TankTurret/WeaponFireLocation

# Contains fired projectiles for scene management
@onready var fired_weapon_container = $FiredWeaponContainer

# This is called a packed scene
# Calling "instantiate" on it is equivalent to an instanced scene
# TODO: This need to be loaded from an inventory component and selected at time of shoot
# for the active weapon
var weapon_project_scene = preload("res://Scenes/Items/WeaponProjectiles/weapon_projectile.tscn")


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
	# Create a scene instance (Spawn)
	var fired_weapon_instance = weapon_project_scene.instantiate()
	
	fired_weapon_instance.global_position = global_position + weapon_fire_location.position
	# Add the instance to the game
	fired_weapon_container.add_child(fired_weapon_instance)
