class_name WeaponNonPhysicalBeam extends Node2D
## An alternative to WeaponProjectile for weapons with non-physical bodies

signal completed_lifespan ## Tracked by Weapon class

## Self destroys once this time has passed.[br]
## When [member kill_after_turns_elapsed] is used, this time emits [signal completed_lifespan].
@export var max_lifetime: float = 10.0

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
