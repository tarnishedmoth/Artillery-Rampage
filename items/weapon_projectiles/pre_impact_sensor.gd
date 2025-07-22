class_name PreImpactSensor extends Node2D

## Checks for collisions in the trajectory.

signal detected

## Node which global_position we'll track to trigger the deployable
@export var tracking:Node2D # Splitting these because there could be cool alternative mechanics
@export var projectile:WeaponProjectile ## The projectile to explode when this sensor triggers.
@export_flags_2d_physics var collision_masks: int
@export_range(15.0, 500.0, 5.0, "or_less", "or_greater") var distance:float = 90.0
@export var time_to_arm:float = 0.4 ## Minimum time after [_ready] before [member detected] can be fired.

@export var show_debug:bool = false

var armed:bool = false

var _last_global_position: Vector2

@onready var debug_sprite: Sprite2D = %DebugSprite

func _ready() -> void:
	if not tracking:
		tracking = get_parent()
	
	await get_tree().create_timer(time_to_arm).timeout
	armed = true
	
	if show_debug:
		debug_sprite.show()
	else:
		debug_sprite.hide()

func _physics_process(_delta: float) -> void:
	if armed && _last_global_position:
		#var velocity:Vector2 = tracking.global_position - _last_global_position
		#
		#var gravity:Vector2 = Vector2.ZERO
		#if tracking is PhysicsBody2D: gravity = tracking.get_gravity() * delta
		#
		#var projected_position:Vector2 = tracking.global_position + velocity + gravity
		
		var cast_position:Vector2 = tracking.global_position + (_last_global_position.direction_to(tracking.global_position) * distance)
		
		if show_debug: debug_sprite.global_position = cast_position
		#if show_debug: debug_sprite.global_position = _last_global_position
		
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		# use global coordinates, not local to node
		var query = PhysicsRayQueryParameters2D.create(tracking.global_position, cast_position, collision_masks)
		query.collide_with_areas = true
		
		var result = space_state.intersect_ray(query)
		
		if result:
			_detected()
		
	_last_global_position = tracking.global_position

func _detected() -> void:
	if projectile:
		projectile.explode_and_force_destroy(null, true)
		
	detected.emit()
	armed = false
