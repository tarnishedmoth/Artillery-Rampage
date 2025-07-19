extends Node2D

signal detected

## Node which global_position we'll track to trigger the deployable
@export var tracking:Node2D # Splitting these because there could be cool alternative mechanics

## Refactored to use a signal connected to WeaponProjectileDeployable.trigger()
#@export var deployable:WeaponProjectileDeployable

## Refactored to simply trigger when Y velocity is positive (going downward)
## Speeds below this number will begin the detonation process
#@export var y_velocity_min_threshold:float = 10.0
#@export var low_vel_frames_to_detonate:int = 2

@onready var _last_position:Vector2 = global_position
var _low_velocity_frames:int = 0

func _physics_process(_delta: float) -> void:
	## Refactored to simply trigger when Y velocity is positive (going downward)
	#var difference = absf(absf(tracking.global_position.y) - absf(_last_position.y))
	##print(difference)
	#if difference < y_velocity_min_threshold:
		#_low_velocity_frames += 1
		#if _low_velocity_frames >= low_vel_frames_to_detonate:
			#deployable.trigger()
			#queue_free()
	#else:
		#_low_velocity_frames = 0
	#_last_position = tracking.global_position
	
	if tracking.global_position.y > _last_position.y:
		detected.emit()
		#deployable.trigger()
		queue_free()
	_last_position = tracking.global_position
