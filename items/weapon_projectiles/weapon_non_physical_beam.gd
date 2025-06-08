class_name WeaponNonPhysicalBeam extends Node2D
## An alternative to WeaponProjectile for weapons with non-physical bodies

signal completed_lifespan ## Tracked by Weapon class

@onready var laser_start = $LaserStart
@onready var laser_end = $LaserEnd

## Self destroys once this time has passed.[br]
## When [member kill_after_turns_elapsed] is used, this time emits [signal completed_lifespan].
@export var max_lifetime: float = 10.0

## How far the beam can travel per second
var speed: float = 800.0

## The angle of the barrel firing the beam. This will be used to determine the trajectory of the beam.
var aim_angle: float

func _ready() -> void:
	if max_lifetime > 0.0: destroy_after_lifetime()

func destroy():
	completed_lifespan.emit()
	queue_free()

func destroy_after_lifetime(lifetime:float = max_lifetime) -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(destroy)
	timer.start(lifetime)

func _process(delta):
	var laser_end_velocity = Vector2(speed * delta, 0.0)
	laser_end.position += laser_end_velocity.rotated(aim_angle)
	
	# Only move laser_start at the end of the beam's lifetime
	#var laser_start_velocity = laser_end_velocity / 100
	#laser_start.position += laser_start_velocity.rotated(aim_angle)
	
	$BeamSprite.global_rotation = aim_angle + deg_to_rad(90)
	$BeamSprite.position =  (laser_end.position + laser_start.position) / 2
	$BeamSprite.scale.y = laser_end.position.length() - laser_start.position.length()
