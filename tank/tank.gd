class_name Tank extends Node2D

# TODO: These maybe should be global events

@warning_ignore("unused_signal")
signal tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D)

@warning_ignore("unused_signal")
signal tank_took_damage(
	tank: Tank, instigatorController: Node2D, instigator: Node2D, amount: float)

@export var min_angle:float = -90
@export var max_angle:float = 90

@export var weapon_max_power_health_mult:float = 10
@export var max_health:float = 100
@export var ground_trace_distance:float = 1000

@export var turret_shot_angle_offset:float = -90

@export var color: Color = Color.WHITE
@export var turret_color_value: float = 0.7

@export_category("Damage")
@export_range(0, 1000) var min_damage_distance: float = 10

# 300^x = 1000 -> Want to lose all health if fall > 300 units
@export_category("Damage")
@export_range(1, 10) var damage_exponent: float = 1.2

@export_category("Damage")
@export_range(0.1, 100) var damage_distance_multiplier: float = 1.0

@onready var tankBody: TankBody = $TankBody
@onready var turret = $TankBody/TankTurret
@onready var weapon_fire_location = $TankBody/TankTurret/WeaponFireLocation

# Contains fired projectiles for scene management
@onready var fired_weapon_container = $FiredWeaponContainer

@onready var bottom_reference_point = $TankBody/Bottom
@onready var top_reference_point = $TankBody/Top

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
	_update_max_power()
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

func take_damage(instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	var orig_health = health
	health = clampf(health - amount, 0, max_health)
	var actual_damage = orig_health - health
	
	if is_zero_approx(actual_damage):
		print("Tank " + name + " didn't take any actual damage")
		return
	
	_update_max_power()
	
	if health > 0 and actual_damage > 0:
		_update_visuals_after_damage()
	
	print("Tank " + name + " took " + str(actual_damage) + " damage; health=" + str(health))
	emit_signal("tank_took_damage", self, instigatorController, instigator, actual_damage)
	if health <= 0:
		emit_signal("tank_killed", self, instigatorController, instigator)

func _update_max_power():
	max_power = health * weapon_max_power_health_mult
	power = minf(power, max_power)
	
func _update_visuals_after_damage():
	# TODO: This is placeholder but right now just darkening the tanks accordingly
	var health_pct = health / max_health
	var dark_pct = 1 - health_pct
	
	modulate = modulate.darkened(dark_pct)
	turret.modulate = turret.modulate.darkened(dark_pct)

func kill():
	print("Tank: " + name + " Killed")
	queue_free()

func snap_to_ground():
	var space_state = get_world_2d().direct_space_state
	# in 2D positive y goes down
	
	var query_params = PhysicsRayQueryParameters2D.create(
		top_reference_point.global_position, top_reference_point.global_position + Vector2(0, ground_trace_distance),
		 Collisions.Layers.terrain)
		
	query_params.exclude = [self]
	
	var result = space_state.intersect_ray(query_params)
	if !result:
		print("tank.snap_to_ground(" + name + "): cannot find ground")
		return 
		
	# Setting the position here will put the center of the tank at the position. Need to offset by the bottom offset
	var ground_position = result["position"]
	var adjusted_ground_position = ground_position - bottom_reference_point.position
	
	print("tank.snap_to_ground(" + name + "): adjusting from " + str(global_position) + " to " + str(adjusted_ground_position))
	
	var fall_damage := _calculate_fall_damage(adjusted_ground_position)
	if fall_damage > 0:
		self.take_damage(owner, self, fall_damage)
	global_position = adjusted_ground_position
	
func _on_reset_orientation(_tankBody: TankBody) -> void:
	snap_to_ground()
	
func _calculate_fall_damage(new_position: Vector2) -> float:
	var dist = (new_position - global_position).length()
	if dist < min_damage_distance:
		print("tank(%s): _calculate_fall_damage - %f < %f -> 0" % [name, dist, min_damage_distance])
		return 0.0
	
	var damage := pow(dist * damage_distance_multiplier, damage_exponent)
	print("tank(%s): _calculate_fall_damage: %f -> %f" % [name, dist, damage])
	
	return damage
