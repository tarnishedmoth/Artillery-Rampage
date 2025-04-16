class_name TankBody extends RigidBody2D

var orig_gravity:float
var queue_reset_orientation: bool = false

@warning_ignore("unused_signal")
signal on_reset_orientation(tankBody: TankBody)

var _original_pos:Vector2

func _ready() -> void:
	orig_gravity = gravity_scale
	_original_pos = position

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

# See https://forum.godotengine.org/t/how-do-i-reset-forces-on-a-rigidbody2d/76619/7
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if queue_reset_orientation:
		_do_reset_orientation(state)
		queue_reset_orientation = false

func _do_reset_orientation(state: PhysicsDirectBodyState2D) -> void:
	print("Tank(%s): _do_reset_orientation" %  [get_parent().get_parent().name])
	toggle_gravity(false)
	
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0
	
	rotation = 0
	
	# Both of the below cause physics glitches
	# Because the tank body is attached to a Node2D its parent position is getting "out of sync" with the rigid body so must correct it
	# var pos_delta:Vector2 = position - _original_pos
	# var parent_2d:Node2D = get_parent() as Node2D
	# if parent_2d:
	# 	parent_2d.position += pos_delta
	# 	position = _original_pos

	# Because the tank body is attached to a Node2D its parent position is getting "out of sync" with the rigid body so must correct it
	# Doing this in _integrate_forces causes physics engine issues and things never "settle"
	# var parent_2d:Node2D = get_parent() as Node2D
	# if parent_2d:
	# 	parent_2d.global_position = global_position

	emit_signal("on_reset_orientation", self)
	
func is_falling() -> bool:
	# TODO: May want to do raycast instead (See parent tank script "get_ground_position"
	# This seems to always return true as they are slightly in motion
	# return !linear_velocity.is_zero_approx() || !is_zero_approx(angular_velocity)
	#var result:bool =  abs(angular_velocity) >= 0.1 || linear_velocity.length_squared() >= 0.001
	
	#print("tank: " +  get_parent().get_parent().name + " (is_falling=" + str(result) + ") - angular_velocity=" + str(angular_velocity) + ";linear_velocity=" + str(linear_velocity.length()))
	var result:bool = !is_sleeping()
	return result
