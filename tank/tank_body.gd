class_name TankBody extends RigidBody2D

var orig_gravity:float
var queue_reset_orientation: bool = false

signal on_reset_orientation(tankBody: TankBody)

func _ready() -> void:
	orig_gravity = gravity_scale

func toggle_gravity(enabled: bool) -> void:
	gravity_scale = orig_gravity if enabled else 0.0

func reset_orientation() -> void:
	queue_reset_orientation = true

# See https://forum.godotengine.org/t/how-do-i-reset-forces-on-a-rigidbody2d/76619/7
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if queue_reset_orientation:
		_do_reset_orientation(state)
		queue_reset_orientation = false

func _do_reset_orientation(state: PhysicsDirectBodyState2D) -> void:
	toggle_gravity(false)
	
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0
	
	rotation = 0
	
	emit_signal("on_reset_orientation", self)
	
func is_falling() -> bool:
	# This seems to always return true as they are slightly in motion
	# return !linear_velocity.is_zero_approx() || !is_zero_approx(angular_velocity)
	var result:bool =  abs(angular_velocity) >= 0.1 || linear_velocity.length_squared() >= 1.0
	
	print("tank: " + name + " (is_falling=" + str(result) + ") - angular_velocity=" + str(angular_velocity) + ";linear_velocity=" + str(linear_velocity.length()))

	return result
