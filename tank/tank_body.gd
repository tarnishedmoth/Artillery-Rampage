class_name TankBody extends RigidBody2D

var orig_gravity:float
var queue_reset_orientation: bool = false
var queue_sleep: bool = false
var freeze_from_sleep:bool = false

@export_category("Quick Sleep")
@export 
var sleep_linear_velocity_threshold = 2.0

@export_category("Quick Sleep")
@export_range(-180, 180, 0.001, "radians_as_degrees") 
var sleep_angular_threshold = deg_to_rad(10.0)

@warning_ignore("unused_signal")
signal on_reset_orientation(tankBody: TankBody)

func _ready() -> void:
	orig_gravity = gravity_scale

func toggle_gravity(enabled: bool) -> void:
	print("Tank(%s): toggle_gravity - %s" % [get_parent().get_parent().name, str(enabled)])
	if enabled:
		# Integrate_forces doesn't seem to be called if there is nothing to do which can happen if there is no falling, so
		# clear this flag so it doesn't get called randomly later 
		queue_reset_orientation = false
		
	gravity_scale = orig_gravity if enabled else 0.0

func is_gravity_enabled() -> bool:
	return gravity_scale > 0.0
func reset_orientation() -> void:
	print("Tank(%s): reset_orientation" % [get_parent().get_parent().name])
	queue_reset_orientation = true

## Request body to go to sleep if velocity thresholds reached
func request_sleep() -> void:
	print("Tank(%s): request_sleep" % [get_parent().get_parent().name])
	queue_sleep = true

# See https://forum.godotengine.org/t/how-do-i-reset-forces-on-a-rigidbody2d/76619/7
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if queue_reset_orientation:
		_do_reset_orientation(state)
		queue_reset_orientation = false
	elif queue_sleep and absf(state.angular_velocity) <= sleep_angular_threshold \
	 and state.linear_velocity.length_squared() <= sleep_linear_velocity_threshold * sleep_linear_velocity_threshold:
		print("Tank(%s): requested sleep from velocity thresholds reached"% [get_parent().get_parent().name])
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		state.sleeping = true
		set_deferred("freeze", true)
		freeze_from_sleep = true
		queue_sleep = false
	elif freeze or gravity_scale == 0.0:
		_reset_physics_state(state)

func _do_reset_orientation(state: PhysicsDirectBodyState2D) -> void:
	print("Tank(%s): _do_reset_orientation" %  [get_parent().get_parent().name])
	toggle_gravity(false)
	
	_reset_physics_state(state)
	rotation = 0
	
	if freeze_from_sleep:
		set_deferred("freeze", false)
		freeze_from_sleep = false
	queue_sleep = false
	
	on_reset_orientation.emit(self)

func _reset_physics_state(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0
	state.set_constant_force(Vector2.ZERO)

func is_falling() -> bool:
	# TODO: May want to do raycast instead (See parent tank script "get_ground_position"
	# This seems to always return true as they are slightly in motion
	# return !linear_velocity.is_zero_approx() || !is_zero_approx(angular_velocity)
	#var result:bool =  abs(angular_velocity) >= 0.1 || linear_velocity.length_squared() >= 0.001
	
	#print("tank: " +  get_parent().get_parent().name + " (is_falling=" + str(result) + ") - angular_velocity=" + str(angular_velocity) + ";linear_velocity=" + str(linear_velocity.length()))
	var result:bool = !is_sleeping() && !freeze
	return result
