extends RigidBody2D

# The idea here is that we are using RigidBody2D for the physics behavior
# and the Area2D as the overlap detection for detecting hits
@export var power_velocity_mult:float = 1

func set_spawn_parameters(power:float, angle:float):
	linear_velocity = Vector2.from_angle(angle) * power * power_velocity_mult
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# TODO: Handle wall overlaps with wall border and overlaps with terrain and tanks
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
