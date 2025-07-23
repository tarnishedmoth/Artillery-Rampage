class_name Tank extends Node2D

signal actions_completed(tank: Tank)
signal tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D)
signal tank_took_damage(
	tank: Tank, instigatorController: Node2D, instigator: Node2D, amount: float)
signal  tank_took_emp(
	tank: Tank, instigatorController: Node2D, instigator: Node2D, amount: float)

signal tank_started_falling(tank: Tank)
signal tank_stopped_falling(tank: Tank)

@export var drop_on_death:PackedScene ## Scene is spawned at tank's global position when it dies.
## Trajectory Indicator for projectile-based weapons
@export var shooting_trajectory_previewer:Weapon
## Trajectory Indicator for beam-based weapons
@export var beam_trajectory_indicator:Weapon

@export var min_angle:float = -90.0
@export var max_angle:float = 90.0

## Weapon power output is decreased when health isn't full.
## @deprecated: Use [member weapon_max_power_range] instead.
@export var weapon_max_power_health_mult:float = 10 # Didn't comment out in case there are scenes with modified export property values
## When [method _update_attributes] is called, [member max_power] is linearly interpolated using ([member health]/[member max_health]) as delta.
@export var weapon_max_power_range:Vector2 = Vector2(300.0,1000.0)
@export var max_health:float = 100.0
@export var ground_trace_distance:float = 1000.0

@export var turret_shot_angle_offset:float = -90 ## @deprecated: - corrected the rotation of the marker2D and math instead

@export var turret_color_value: float = 0.7

@export var lights:Array[CanvasItem]

@export_category("Damage")
@export_group("Fall Damage")
@export var enable_fall_damage:bool = true
@export_range(0, 1000) var min_damage_distance: float = 10
# (300*0.1)^x = 100 -> Want to lose all health if fall > 300 units
@export_range(1, 10) var damage_exponent: float = 1.36
@export_range(0.01, 100) var damage_distance_multiplier: float = 0.1

@export_group("Damage Error")
@export var enable_new_error_damage = false
@export var max_power_v_health:Curve
@export var aim_deviation_v_health:Curve

@export_group("Materials")
@export var damage_material:ShaderMaterial
@export_range(1.0, 10.0, 0.1) var damage_flash_duration: float = 2.0
var damage_timer:Timer

@onready var tankBody: TankBody = $TankBody

@onready var bottom_reference_point = $TankBody/Bottom
@onready var top_reference_point = $TankBody/Top
@onready var left_reference_point = $TankBody/Left
@onready var right_reference_point = $TankBody/Right

@onready var turret = $TankBody/TankTurret
@onready var weapon_fire_location = $TankBody/TankTurret/WeaponFireLocation

@onready var weapons: Array[Weapon]
var current_equipped_weapon: Weapon
var current_equipped_weapon_index: int = -1

@onready var fall_damage_causer: FallDamageCauser = %FallDamageCauser
@onready var parachute = %Parachute
@onready var parachute_pack = %ParachuteBackpack

# used to check whether the parachute should deploy or not when tank falls
var has_parachute:bool = false:
	set(value):
		has_parachute = value
		if value:
			parachute_pack.show()
		else:
			parachute_pack.hide()
			
var health: float:
	set(value):
		health = clampf(value, 0.0, max_health)
		if not is_equal_approx(health, max_health):
			_update_attributes()
	get:
		return health

var power:float
var max_power:float
var angle_deviation:float

var fall_start_position: Vector2
var mark_falling: bool

var previewer_disabled:bool = false

# Effects
@export_group("Debuffs (EMP, ...)", "debuff_")
var emp_charge:float:
	set(value):
		debuff_emp_charge = value
	get:
		return debuff_emp_charge
var debuff_emp_charge:float = 0.0:
	set(value):
		debuff_emp_charge = maxf(value, 0.0)
@export var debuff_disabling_emp_charge_threshold = 50.0 ## This much charge will "disable" this tank preventing it from shooting
@export var debuff_emp_conductivity_multiplier:float = 1.0 ## Incoming charge is multiplied by this figure
@export var debuff_emp_discharge_per_turn:float = 60.0 ## This much charge is subtracted each turn end.

@export_group("")
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		_on_update_color()
	get:
		return color

#@onready var controller:TankController = get_parent()
@onready var controller = get_parent()
@onready var damaged_smoke_particles: GPUParticles2D = %DamagedSmokeParticles

var tank_decor_light_color:Color = Color.WHITE:
	set(value):
		tank_decor_light_color = UIUtils.desaturate(value, 0.16) # 16% desaturated
		
		for light in lights:
			light.color = tank_decor_light_color

func _on_update_color():
	modulate = color
	tank_decor_light_color = color # Using the setter to config multiple lights
	# TODO: Setter is not supposed to be called for @onready or initial value but it is so guard against initial nil
	if turret:
		turret.modulate = color.darkened(1 - turret_color_value)

func _ready() -> void:
	GameEvents.turn_ended.connect(_on_turn_ended)
	# Need to duplicate as we are using a uniform for the start_time and this is shared on all instances
	# As not using "instance uniform" as this isn't available in compatibility rendering needed for web
	if damage_material:
		damage_material = damage_material.duplicate()

	_on_update_color()
	for light in lights:
		light.hide()
	scan_available_weapons()

	health = max_health

	damaged_smoke_particles.emitting = false

	# Setters not called in _ready so need to call this manually
	_update_attributes()

	power = max_power

	# Make sure to do snap_to_ground from the physics task
	tankBody.connect("on_reset_orientation", _on_reset_orientation)

	# TODO: Using this in conjunction with falling detection
	tankBody.contact_monitor = true
	tankBody.max_contacts_reported = 1

func _exit_tree() -> void:
	disconnect_from_weapons()

func _to_string() -> String:
	return name

## Returns the bounds of the tank in local coordinates
func get_rect() -> Rect2:
	var width:float = right_reference_point.position.x - left_reference_point.position.x
	var height: float = bottom_reference_point.position.y - top_reference_point.position.y

	var center = position
	var top_left = center - Vector2(width * 0.5, height * 0.5)

	return Rect2(top_left, Vector2(width, height))

func apply_pending_state(state: PlayerState) -> void:
	# TODO: This feels hacky but _ready has already run for children when this is called
	scan_available_weapons()
	max_health = state.max_health
	health = state.health

	_update_visuals_after_damage(false)

func populate_player_state(state: PlayerState) -> void:
	state.max_health = max_health
	state.health = health

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	global_position = tankBody.global_position
	tankBody.position = Vector2.ZERO
	
	if not tankBody.is_gravity_enabled() or tankBody.freeze:
		# Make sure we emit a stop falling if started falling
		if mark_falling:
			stopped_falling()
		return

	# Check for falling
	var falling := is_falling()
	if falling:
		started_falling()
	else:
		stopped_falling()

func toggle_gravity(enabled: bool) -> void:
	tankBody.toggle_gravity(enabled)

func request_sleep() -> void:
	tankBody.request_sleep()
	
func is_falling() -> bool:
	# TODO: contact monitoring replaces need for doing trace tests and is more accurate so can clean this up
	# If still want "snap_to_ground" the falling trace test may still be useful
	#var result := _is_falling_trace_test() # || tankBody.is_falling()
	#var result := tankBody.get_contact_count() == 0
	var result := tankBody.get_contact_count() == 0 or tankBody.is_falling()
	return result

func reset_orientation() -> void:
	tankBody.reset_orientation()

#region Aim and Power

func aim_at(angle_rads: float) -> void:
	turret.rotation = clampf(angle_rads, deg_to_rad(min_angle), deg_to_rad(max_angle))

	#Still fire event when no change for legacy purposes
	GameEvents.aim_updated.emit(owner)

func can_aim_at(angle_rads: float) -> bool:
	var angle_degs:float = rad_to_deg(angle_rads)
	return angle_degs >= min_angle and angle_degs <= max_angle
	
func aim_delta(angle_rads_delta: float) -> void:
	aim_at(turret.rotation + angle_rads_delta)
	
func can_aim_delta(angle_rads_delta: float) -> bool:
	return can_aim_at(turret.rotation + angle_rads_delta)
	
## [0-100]
func set_power_percent(power_pct: float) -> void:
	power = clampf(power_pct * max_power / 100.0, 0.0, max_power)
	#print_debug("power_pct=" + str(power_pct) + "; power=" + str(power))
	GameEvents.power_updated.emit(owner)

## [0-100]
func set_power_delta(power_pct_delta: float) -> void:
	#print_debug("set_power_delta=" + str(power_pct_delta))
	set_power_percent(power / max_power * 100 + power_pct_delta)

func get_turret_rotation() -> float:
	return turret.rotation

func _update_attributes():
	#max_power = health * weapon_max_power_health_mult
	var health_delta = clampf(health / max_health, 0.01, 1.0)

	if enable_new_error_damage:
		max_power = weapon_max_power_range.y * max_power_v_health.sample(health_delta)
		# Once an angle inaccuracy set use the same one for subsequent damage to avoid too much guesswork for the player
		var angle_error_sign:float = signf(angle_deviation) if not is_zero_approx(angle_deviation) else MathUtils.randf_sgn()
		var previous_deviation:float = angle_deviation
		angle_deviation = angle_error_sign * aim_deviation_v_health.sample(health_delta)
		get_weapon_fire_locations().rotation_degrees += angle_deviation - previous_deviation
	# if the AimDamageWobble node is present then we don't change max power
	elif get_children().any(func(c:Node) -> bool: return c is AimDamageWobble):
		max_power = weapon_max_power_range.y
	else:
		max_power = lerpf(weapon_max_power_range.x, weapon_max_power_range.y, health_delta)

	power = minf(power, max_power)

	print_debug("tank(%s): _update_attributes - health_delta=%f; power=%f; max_power=%f; angle_deviation=%f" % [get_parent().name, health_delta, power, max_power, angle_deviation])
#endregion

## If the weapon can be fired, return true, else false.
func shoot() -> bool:
	var weapon: Weapon = get_equipped_weapon()
	if check_can_shoot_weapon(weapon):
		controller.submit_intended_action(_shoot_weapon.bind(weapon, power), controller)
		return true
	else:
		weapon.dry_fire() # For sound effect (if assigned in Weapon scene)
		return false
		
func _shoot_weapon(weapon:Weapon, _power:float) -> void:
	kill_active_previewer()
	weapon.shoot(_power)
	
func kill_active_previewer(until_next_turn:bool = true) -> void:
	if shooting_trajectory_previewer:
		shooting_trajectory_previewer.kill_all_projectiles()
	if beam_trajectory_indicator:
		beam_trajectory_indicator.kill_all_projectiles()
	
	if until_next_turn:
		previewer_disabled = true
		await GameEvents.turn_ended
		previewer_disabled = false

#region Damage and Death
func take_damage(instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	var orig_health = health
	# Calls setter and automatically clamps
	health = health - amount
	var actual_damage = orig_health - health

	if is_zero_approx(actual_damage):
		print_debug("Tank %s didn't take any actual damage" % [get_parent().name])
		return

	if health > 0 and actual_damage > 0:
		_update_visuals_after_damage()

	print_debug("Tank %s took %f damage; health=%f" % [ get_parent().name, actual_damage, health])
	tank_took_damage.emit(self, instigatorController, instigator, actual_damage)

	if health <= 0:
		tank_killed.emit(self, instigatorController, instigator)

func take_emp(instigatorController: Node2D, instigator: Node2D, charge:float) -> void:
	var actual_charge = charge * debuff_emp_conductivity_multiplier
	debuff_emp_charge += actual_charge

	print_debug("Tank %s took %f EMP charge; total=%f" % [ get_parent().name, actual_charge, debuff_emp_charge])
	tank_took_emp.emit(self, instigatorController, instigator, actual_charge)

func kill():
	print_debug("Tank: %s Killed" % [get_parent().name])
	_separate_particles_to_despawn(damaged_smoke_particles)
	if drop_on_death:
		spawn_death_drop()
	GameEvents.player_died.emit(controller)
	queue_free()

func spawn_death_drop() -> void:
	if drop_on_death:
		var spawn = drop_on_death.instantiate()
		spawn.global_position = global_position
		var container = _get_scene_container()
		container.add_child.call_deferred(spawn)

func _separate_particles_to_despawn(particles:GPUParticles2D) -> void:
	particles.reparent(_get_scene_container())
	particles.emitting = false
	particles.finished.connect(particles.queue_free)

func _get_scene_container() -> Node2D:
	var container = SceneManager.get_current_level_root()
	if container == null:
		container = SceneManager.current_scene
	if container.has_method("get_container"):
		container = container.get_container()
	return container

func _update_visuals_after_damage(damage_shader:bool = true):
	var threshold = 0.75
	if (health/max_health) <= threshold: # Percentage
		if not damaged_smoke_particles.emitting:
			damaged_smoke_particles.emitting = true
			
		var health_ratio:float = 1.0-(health/(max_health*threshold))
		damaged_smoke_particles.amount_ratio = lerp(0.2, 1.0, health_ratio)
		damaged_smoke_particles.lifetime = lerpf(2.8, 6.5, health_ratio)

	var health_pct:float = health / max_health
	var dark_pct:float = 1 - health_pct

	modulate = modulate.darkened(dark_pct)
	turret.modulate = turret.modulate.darkened(dark_pct)

	if damage_shader:
		_activate_damage_shader()

func _activate_damage_shader() -> void:
	if material:
		#print_debug("Tank: %s - ignore as shader already set" % get_parent().name)
		return
	if not damage_material:
		#print_debug("Tank: %s - no damage material" % get_parent().name)
		return

	var game_time_seconds: float = SceneManager.get_current_level_root().game_timer.time_seconds if SceneManager.get_current_level_root() else 0.0
	damage_material.set_shader_parameter("start_time", game_time_seconds)

	material = damage_material

	# Set timer to expire
	if not damage_timer:
		damage_timer = Timer.new()
		damage_timer.wait_time = damage_flash_duration
		damage_timer.one_shot = true
		damage_timer.autostart = false
		damage_timer.timeout.connect(func():
			print_debug("Tank: %s - damage timer expired" % get_parent().name)
			material = null
		)
		add_child(damage_timer)

	damage_timer.start()
#endregion

#region Movement
func snap_to_ground():
	# Setting the position here will put the center of the tank at the position. Need to offset by the bottom offset
	var ground_position = get_ground_snap_position()

	print_debug("tank.snap_to_ground(%s): adjusting from %s to %s"
		% [get_parent().name, tankBody.global_position, ground_position])

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
		print_debug("tank._ground_trace(%s): already colliding with body %s" % [get_parent().name, tankBody.get_colliding_bodies()[0].name])
		return bottom_reference_point.global_position

	var space_state := get_world_2d().direct_space_state

	# in 2D positive y goes down
	var query_params := PhysicsRayQueryParameters2D.create(
		top_reference_point.global_position, top_reference_point.global_position + Vector2(0, trace_distance),
		 Collisions.CompositeMasks.tank_snap)

	query_params.exclude = [self]

	var result = space_state.intersect_ray(query_params)
	if !result:
		print_debug("tank._ground_trace(%s): cannot find ground" % [get_parent().name])
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
	if !enable_fall_damage:
		print_debug("tank(%s): _check_and_emit_fall_damage - fall damage disabled" % [get_parent().name])
		return
	var fall_damage := _calculate_fall_damage(start_position, end_position)
	if fall_damage > 0:
		var instigator_controller:TankController = fall_damage_causer.instigator_controller if fall_damage_causer.instigator_controller else owner
		self.take_damage(instigator_controller, self, fall_damage)

func _calculate_fall_damage(start_position: Vector2, end_position: Vector2) -> float:
	var dist = (end_position - start_position).length()
	if dist < min_damage_distance:
		print_debug("tank(%s): _calculate_fall_damage - %f < %f -> 0" % [get_parent().name, dist, min_damage_distance])
		return 0.0

	var damage := pow(dist * damage_distance_multiplier, damage_exponent)
	print_debug("tank(%s): _calculate_fall_damage: %f -> %f" % [get_parent().name, dist, damage])

	return damage

func started_falling() -> void:
	if has_parachute:
		parachute.show()
		parachute_pack.hide()
	if mark_falling:
		return
	print_debug("tank(%s) started falling at position=%s" % [get_parent().name, str(tankBody.global_position)])
	fall_start_position = tankBody.global_position
	mark_falling = true
	tank_started_falling.emit(self)

func stopped_falling() -> void:
	if has_parachute:
		parachute.hide()
		parachute_pack.show()
	if !mark_falling:
		return

	print_debug("tank(%s) stopped falling at position=%s" % [get_parent().name, str(tankBody.global_position)])
	_check_and_emit_fall_damage(fall_start_position, tankBody.global_position)
	mark_falling = false
	tank_stopped_falling.emit(self)

#endregion

#region Weapon Use
func get_weapon_fire_locations() -> Marker2D:
	## Only returns one item not multiple!
	return weapon_fire_location

func get_fired_weapon_container() -> Node: return _get_scene_container()
	#var root = SceneManager.get_current_level_root()
	#if root == null:
		#root = SceneManager.current_scene
	#if root.has_method("get_container"):
		#return root.get_container()
	#else: return self

func set_equipped_weapon(index:int) -> void:
	if current_equipped_weapon in weapons:
		current_equipped_weapon.unequip()

	current_equipped_weapon_index = index
	current_equipped_weapon = weapons[index]
	current_equipped_weapon.equip()
	_on_weapon_changed(current_equipped_weapon)

func get_equipped_weapon() -> Weapon:
	if current_equipped_weapon in weapons:
		return current_equipped_weapon

	# Our last weapon was lost/destroyed
	equip_next_weapon()
	if not current_equipped_weapon in weapons:
		return null
	else:
		return current_equipped_weapon # Ugly but rather this than recursion

## Returns false if weapon can't shoot, or true if it can.
func check_can_shoot_weapon(weapon: Weapon) -> bool:
	if weapon == null:
		push_warning(str(self)+": Tried to shoot, but equipped weapon is null.")
		return false
	else:
		if not weapon.use_ammo or weapon.current_ammo > 0 or weapon.can_reload():
			return true
		else:
			# Out of ammo.
			return false

func scan_available_weapons() -> void:
	weapons.clear()

	if shooting_trajectory_previewer:
		shooting_trajectory_previewer.connect_to_tank(self)
	if beam_trajectory_indicator:
		beam_trajectory_indicator.connect_to_tank(self)

	var parent = get_parent()
	if parent is TankController:
		weapons = parent.get_weapons()
	for w in weapons:
		#w.barrels.append(weapon_fire_location) # Moved to Weapon class
		w.connect_to_tank(self)
	equip_next_weapon()

func disconnect_from_weapons() -> void:
	for w in weapons:
		w.disconnect_from_tank(self)

func equip_prev_weapon() -> void:
	equip_weapon_at_index(current_equipped_weapon_index - 1)

func equip_next_weapon() -> void:
	equip_weapon_at_index(current_equipped_weapon_index + 1)

func equip_weapon_at_index(index: int) -> void:
	if weapons.is_empty():
		printt(self,"No weapons available to equip.")
		return
	if index < 0:
		index = weapons.size() - 1
	elif index >= weapons.size():
		index = 0
	set_equipped_weapon(index)
	prints(self,"cycled weapon to", current_equipped_weapon.display_name)

func next_weapon_mode() -> void:
	var weapon = get_equipped_weapon()
	weapon.next_mode()

func push_weapon_update_to_hud(weapon: Weapon = get_equipped_weapon()) -> void:
	GameEvents.weapon_updated.emit(weapon)

## This method is not used by this class, instead it's used by [Player].
func visualize_trajectory() -> void:
	if previewer_disabled: return
	if current_equipped_weapon:
		match current_equipped_weapon.trajectory_indicator_type:
			Weapon.TRAJECTORY_TYPES.BEAM:
				if beam_trajectory_indicator:
					beam_trajectory_indicator.shoot(power)
			
			Weapon.TRAJECTORY_TYPES.PROJECTILE:
				if shooting_trajectory_previewer:
					# Lets be real I was definitely better off rigging Weapon to show its trajectory innately
					# instead of trying to mirror another object on the fly lol but this works.
					shooting_trajectory_previewer.power_launch_speed_mult = current_equipped_weapon.power_launch_speed_mult
					var projectile_data = current_equipped_weapon.get_projectile_instance()
					if "mass" in projectile_data:
						shooting_trajectory_previewer.enforce_projectile_property("mass", projectile_data.mass)
					if "is_affected_by_wind" in projectile_data:
						shooting_trajectory_previewer.enforce_projectile_property("is_affected_by_wind", projectile_data.is_affected_by_wind)
					if "gravity_scale" in projectile_data:
						shooting_trajectory_previewer.enforce_projectile_property("gravity_scale", projectile_data.gravity_scale)

					shooting_trajectory_previewer.shoot(power)


func _on_weapon_destroyed(weapon: Weapon) -> void:
	weapons.erase(weapon)

	# Guard against errors similar to the following:
	# Tank.gd:304 @ get_equipped_weapon(): Attempted to find an invalid (previously freed?) object instance into a 'TypedArray.
	# Could check is_instance_valid but simpler and more idomatic to just set to null after free
	if weapon == current_equipped_weapon:
		current_equipped_weapon = null

func _on_weapon_ammo_changed(_new_ammo:int) -> void:
	push_weapon_update_to_hud()

func _on_weapon_magazines_changed(_new_mags:int) -> void:
	push_weapon_update_to_hud()
	
func _on_weapon_mode_changed(_new_mode:int) -> void:
	push_weapon_update_to_hud()

func _on_weapon_changed(new_weapon: Weapon) -> void:
	push_weapon_update_to_hud(new_weapon)

## TURN CHANGE
func _on_weapon_actions_completed(_weapon: Weapon) -> void:
	# ---TURN CHANGEOVER HAPPENS HERE---
	# More than one action / phase could be supported
	actions_completed.emit(self)

func _on_turn_ended(player: TankController) -> void:
	if player == controller: # Our tank
		if debuff_emp_charge > 0.0:
			debuff_emp_charge = maxf(debuff_emp_charge - debuff_emp_discharge_per_turn, 0.0)
#endregion

#region AI Helpers

func get_body_reference_points_local() -> PackedVector2Array:
	return [
		top_reference_point.position,
		right_reference_point.position,
		left_reference_point.position,
		bottom_reference_point.position
	]

func get_body_reference_points_global() -> PackedVector2Array:
	return [
		top_reference_point.global_position,
		right_reference_point.global_position,
		left_reference_point.global_position,
		bottom_reference_point.global_position
	]

#endregion
