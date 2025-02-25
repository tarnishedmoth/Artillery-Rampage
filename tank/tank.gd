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

# (300*0.1)^x = 100 -> Want to lose all health if fall > 300 units
@export_category("Damage")
@export_range(1, 10) var damage_exponent: float = 1.36

@export_category("Damage")
@export_range(0.01, 100) var damage_distance_multiplier: float = 0.1

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
const weapon_project_scene = preload("res://items/weapon_projectiles/weapon_projectile.tscn")

var health: float

var power:float
var max_power:float

var fall_start_position: Vector2
var mark_falling: bool

func _ready() -> void:
	modulate = color
	turret.modulate = color.darkened(1 - turret_color_value)
	
	health = max_health
	_update_max_power()
	power = max_power
	
	# Make sure to do snap_to_ground from the physics task
	tankBody.connect("on_reset_orientation", _on_reset_orientation)
	
	# TODO: Using this in conjunction with falling detection
	tankBody.contact_monitor = true
	tankBody.max_contacts_reported = 1

func _physics_process(delta: float) -> void:
	if !tankBody.is_gravity_enabled():
		return
	
	position = tankBody.position
	global_position = tankBody.global_position
	
	# Check for falling
	var falling := is_falling()
	if falling:
		started_falling()
	else:
		stopped_falling()
	
func toggle_gravity(enabled: bool) -> void:
	tankBody.toggle_gravity(enabled)
	
func is_falling() -> bool:
	# TODO: contact monitoring replaces need for doing trace tests and is more accurate so can clean this up
	# If still want "snap_to_ground" the falling trace test may still be useful
	#var result := _is_falling_trace_test() # || tankBody.is_falling()
	#var result := tankBody.get_contact_count() == 0
	var result := tankBody.get_contact_count() == 0 or tankBody.is_falling()
	return result
	
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
		print("Tank " + get_parent().name + " didn't take any actual damage")
		return
	
	_update_max_power()
	
	if health > 0 and actual_damage > 0:
		_update_visuals_after_damage()
	
	print("Tank " + get_parent().name + " took " + str(actual_damage) + " damage; health=" + str(health))
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
	# Setting the position here will put the center of the tank at the position. Need to offset by the bottom offset
	var ground_position = get_ground_snap_position()
		
	print("tank.snap_to_ground(" + get_parent().name + "): adjusting from " + str(tankBody.global_position) + " to " + str(tankBody.global_position))
	
	_check_and_emit_fall_damage(tankBody.global_position, ground_position)
	
	tankBody.global_position = ground_position
	
func get_ground_snap_position() -> Vector2:
	# Setting the position here will put the center of the tank at the position. Need to offset by the bottom offset
	var ground_position := _ground_trace(ground_trace_distance)
	var adjusted_ground_position = ground_position - bottom_reference_point.position
	
	return adjusted_ground_position
	
func _ground_trace(trace_distance: float) -> Vector2:
	# If already overlapping something then just return the current position
	if tankBody.get_contact_count() > 0:
		#print("tank._ground_trace(%s): already colliding with body %s" % [get_parent().name, tankBody.get_colliding_bodies()[0].name])
		return bottom_reference_point.global_position 
		
	var space_state = get_world_2d().direct_space_state
	
	# in 2D positive y goes down
	var query_params = PhysicsRayQueryParameters2D.create(
		top_reference_point.global_position, top_reference_point.global_position + Vector2(0, trace_distance),
		 Collisions.CompositeMasks.tank_snap)
		
	query_params.exclude = [self]
	
	var result = space_state.intersect_ray(query_params)
	if !result:
		print("tank._ground_trace(" + get_parent().name + "): cannot find ground")
		return tankBody.global_position + Vector2(0, trace_distance)
		
	# Setting the position here will put the center of the tank at the position. Need to offset by the bottom offset
	var ground_position = result["position"]
	
	#print("Tank(%s): _ground_trace - collider=%s; position=%s" % [get_parent().name, result["collider"].get_parent().name, str(ground_position)])
	return ground_position

func _is_falling_trace_test() -> bool:
	var trace_distance: float = 1000 # (top_reference_point.position - bottom_reference_point.position).length() + 1
	var ground_position: Vector2 = _ground_trace(trace_distance)
	var tank_bottom: Vector2 = bottom_reference_point.global_position
	
	# Delta check for position
	var delta_dist: float = absf(ground_position.y - tank_bottom.y)
	
	#draw_rect(Rect2(tank_bottom.x - 25, tank_bottom.y, 50, delta_dist), Color.RED)

	#print("tank(%s): _is_falling_trace_test - ground_pos=%s; tank_bottom=%s; global_pos=%s; delta_dist=%f" % [get_parent().name, str(ground_position), str(tank_bottom), str(global_position), delta_dist])
	return delta_dist > 1

func _on_reset_orientation(_tankBody: TankBody) -> void:
	# TODO: Removing this temporarily as it is proving buggy
	# snap_to_ground()
	pass

func _check_and_emit_fall_damage(start_position: Vector2, end_position: Vector2) -> void:
	var fall_damage := _calculate_fall_damage(start_position, end_position)
	if fall_damage > 0:
		self.take_damage(owner, self, fall_damage)
		
func _calculate_fall_damage(start_position: Vector2, end_position: Vector2) -> float:
	var dist = (end_position - start_position).length()
	if dist < min_damage_distance:
		print("tank(%s): _calculate_fall_damage - %f < %f -> 0" % [get_parent().name, dist, min_damage_distance])
		return 0.0
	
	var damage := pow(dist * damage_distance_multiplier, damage_exponent)
	print("tank(%s): _calculate_fall_damage: %f -> %f" % [get_parent().name, dist, damage])
	
	return damage

func started_falling() -> void:
	if mark_falling:
		return
	print("tank(%s) started falling at position=%s" % [get_parent().name, str(tankBody.global_position)])
	fall_start_position = tankBody.global_position
	mark_falling = true

func stopped_falling() -> void:
	if !mark_falling:
		return
	
	print("tank(%s) stopped falling at position=%s" % [get_parent().name, str(tankBody.global_position)])
	_check_and_emit_fall_damage(fall_start_position, tankBody.global_position)
	mark_falling = false
