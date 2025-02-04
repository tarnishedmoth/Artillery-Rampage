class_name WeaponProjectile extends RigidBody2D

#TODO: We might not need the Overlap if we only have the weapon projectile interact with Area2D's and not other physics bodies

# The idea here is that we are using RigidBody2D for the physics behavior
# and the Area2D as the overlap detection for detecting hits
@export var power_velocity_mult:float = 1

@onready var overlap = $Overlap

var owner_tank: Tank;

func set_spawn_parameters(owner_tank: Tank, power:float, angle:float):
	self.owner_tank = owner_tank
	linear_velocity = Vector2.from_angle(angle) * power * power_velocity_mult
	
func _ready() -> void:
	overlap.connect("body_entered", on_body_entered)

func _process(delta: float) -> void:
	pass
	
func on_body_entered(body: Node2D):
	if body.owner is Tank:
		on_hit_tank(body.owner)

func destroy():
	GameEvents.emit_turn_ended(owner_tank.owner)
	queue_free()
		
func on_hit_tank(tank: Tank):
	print("HIT TANK!")
	# Destroy tank and projectile
	# TODO: Will need to support radial damage that falls off
	# Need concept of area of effect for projectile
	tank.take_damage(owner_tank, self, 10000)
	destroy()
