class_name WeaponProjectile extends RigidBody2D

#TODO: We might not need the Overlap if we only have the weapon projectile interact with Area2D's and not other physics bodies

# The idea here is that we are using RigidBody2D for the physics behavior
# and the Area2D as the overlap detection for detecting hits
@export var power_velocity_mult:float = 1

@onready var overlap = $Overlap

func set_spawn_parameters(power:float, angle:float):
	linear_velocity = Vector2.from_angle(angle) * power * power_velocity_mult
	
func _ready() -> void:
	overlap.connect("body_entered", on_body_entered)

func _process(delta: float) -> void:
	pass
	
func on_body_entered(body: Node2D):
	if body.owner is Tank:
		on_hit_tank(body.owner)
		
func on_hit_tank(tank: Tank):
	print("HIT TANK!")
	# Destroy tank and projectile
	tank.queue_free()
	self.queue_free()
	
