class_name TankBody extends RigidBody2D

var orig_gravity:float
var queue_reset_orientation: bool = false

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
