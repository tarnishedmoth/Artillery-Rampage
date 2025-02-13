class_name Tank extends Node2D

# TODO: These maybe should be global events

@warning_ignore("unused_signal")
signal tank_killed(tank: Tank, instigatorController: Node2D, weapon: WeaponProjectile)

@warning_ignore("unused_signal")
signal tank_took_damage(
	tank: Tank, instigatorController: Node2D, weapon: WeaponProjectile, amount: float)

@export var min_angle:float = -90
@export var max_angle:float = 90

@export var weapon_max_power_health_mult:float = 10
@export var max_health:float = 100
@export var ground_trace_distance:float = 500

@export var turret_shot_angle_offset:float = -90

@export var color: Color = Color.WHITE
@export var turret_color_value: float = 0.7

@onready var tankBody: TankBody = $TankBody
@onready var turret = $TankBody/TankTurret
@onready var weapon_fire_location = $TankBody/TankTurret/WeaponFireLocation

# Contains fired projectiles for scene management
@onready var fired_weapon_container = $FiredWeaponContainer

@onready var bottom_reference_point = $TankBody/Bottom

# This is called a packed scene
# Calling "instantiate" on it is equivalent to an instanced scene
# TODO: This need to be loaded from an inventory component and selected at time of shoot
# for the active weapon
var weapon_project_scene = preload("res://items/weapon_projectiles/weapon_projectile.tscn")

var health: float

var power:float
var max_power:float

func _ready() -> void:
	modulate = color
	turret.modulate = color.darkened(1 - turret_color_value)
	
	health = max_health
	# TODO: Will be set by function based on player controller and be clamped to min,max
	max_power = max_health * weapon_max_power_health_mult
	power = max_power
	
	# Make sure to do snap_to_ground from the physics task
	tankBody.connect("on_reset_orientation", _on_reset_orientation)
	
func toggle_gravity(enabled: bool) -> void:
	tankBody.toggle_gravity(enabled)
	
func is_falling() -> bool:
	return tankBody.is_falling()
	
func reset_orientation() -> void:
	tankBody.reset_orientation()
		
func aim_at(angle_rads: float) -> void:
	turret.rotation = clampf(angle_rads, deg_to_rad(min_angle), deg_to_rad(max_angle))
	GameEvents.emit_aim_updated(owner)
	
func aim_delta(angle_rads_delta: float) -> void:
	aim_at(turret.rotation + angle_rads_delta)
	
func set_power_percent(power_pct: float) -> void:
	power = clampf(power_pct * max_power / 100.0, 0.0, max_power)
	print("power_pct=" + str(power_pct) + "; power=" + str(power))
	GameEvents.emit_power_updated(owner)
	
func set_power_delta(power_pct_delta: float) -> void:
	print("set_power_delta=" + str(power_pct_delta))
	set_power_percent(power / max_power * 100 + power_pct_delta)
	GameEvents.emit_power_updated(owner)

func get_turret_rotation() -> float:
	return turret.rotation
	
func shoot() -> void:
	# Create a scene instance (Spawn)
	var fired_weapon_instance = weapon_project_scene.instantiate()
	
	fired_weapon_instance.global_position = weapon_fire_location.global_position
	fired_weapon_instance.set_spawn_parameters(self, power, turret.global_rotation + deg_to_rad(turret_shot_angle_offset))
	
	# Add the instance to the game
	fired_weapon_container.add_child(fired_weapon_instance)

func take_damage(instigatorController: Node2D, weapon: WeaponProjectile, amount: float) -> void:
	var orig_health = health
	health = clampf(health - amount, 0, max_health)
	var actual_damage = orig_health - health
	
	print("Tank " + name + " took " + str(actual_damage) + " damage; health=" + str(health))
	# TODO: don't emit if damage zero
	emit_signal("tank_took_damage", self, instigatorController, weapon, actual_damage)
	if health <= 0:
		emit_signal("tank_killed", self, instigatorController, weapon)
		
func kill():
	print("Tank: " + name + " Killed")
	queue_free()

func snap_to_ground():
	var space_state = get_world_2d().direct_space_state
	# in 2D positive y goes down
	# Terrain is 4th bit
	var terrain_mask:int = 1 << 3
	
	var query_params = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, ground_trace_distance), terrain_mask)
	query_params.exclude = [self]
	
	var result = space_state.intersect_ray(query_params)
	if !result:
		print("tank.snap_to_ground(" + name + "): cannot find ground")
		return 
		
	# Setting the position here will put the center of the tank at the position. Need to offset by the bottom offset
	var ground_position = result["position"]
	var adjusted_ground_position = ground_position - bottom_reference_point.position
	
	print("tank.snap_to_ground(" + name + "): adjusting from " + str(global_position) + " to " + str(adjusted_ground_position))
	global_position = adjusted_ground_position
	
func _on_reset_orientation(tankBody: TankBody) -> void:
	snap_to_ground()
