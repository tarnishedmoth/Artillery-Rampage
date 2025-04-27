class_name ShatterableObject extends Node2D

# Set to value greater than zero to amortize the cost of creating physics bodies over multiple frames
@export var max_new_bodies_per_frame:int = -1

@onready var _destructible_shape_calculator: DestructibleShapeCalculator = $DestructibleShapeCalculator
@onready var _body_container:Node = $BodyContainer

var _shatter_in_progress:bool = false

@warning_ignore("unused_signal")
signal destroyed(object: ShatterableObject)

@warning_ignore("unused_signal")
signal body_deleted(body: Node2D)

func _ready() -> void:
	body_deleted.connect(_on_body_deleted)
	
	for body in _body_container.get_children():
		body.owner = self		

func damage(body: ShatterableObjectBody, projectile: WeaponProjectile, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	print_debug("%s - body=%s damaged by %s with poly_scale=%s" % [name, body.name, projectile.name, poly_scale])
	
	if _shatter_in_progress:
		print_debug("%s: damage - shatter already in progress - ignoring new damage event" % name)
		return
	if is_queued_for_deletion():
		print_debug("%s: damage - ignoring as object already queued for deletion" % name)
		return
	
	# Avoid multi-shot projectiles from triggering a fury of shatter events in a single frame and undefined behavior
	_shatter_in_progress = true
	
	# TODO: Cache this for given frame and event
	var projectile_poly: CollisionPolygon2D = projectile.get_destructible_component()
	var projectile_poly_global: PackedVector2Array = _destructible_shape_calculator.get_projectile_poly_global(projectile_poly, poly_scale)
	
	var additional_pieces: Array[Node2D] = await body.shatter(projectile, projectile_poly_global)

	for i in additional_pieces.size():
		var new_body: Node2D = additional_pieces[i]
		if max_new_bodies_per_frame > 0:
			var new_rigid_body: RigidBody2D = new_body as RigidBody2D
			if new_rigid_body:
				new_rigid_body.freeze = true
		_body_container.call_deferred("add_child", new_body)
		# Add shatter across multiple frames to avoid lag spikes
		if max_new_bodies_per_frame > 0 and i % max_new_bodies_per_frame == 0:
			# Wait for the physics frame to ensure the new bodies are added to the physics world
			# before unfreezing them
			await get_tree().physics_frame
	
	# Now unfreeze
	if max_new_bodies_per_frame > 0:
		(func() -> void:
			for new_body in additional_pieces:
				var new_rigid_body: RigidBody2D = new_body as RigidBody2D
				if new_rigid_body:
					new_rigid_body.freeze = false
		).call_deferred()

	_delay_shatter_complete()

func shatter(body: ShatterableObjectBody, impact_velocity: Vector2, contact_point: Vector2) -> void:
	print_debug("%s - body=%s shatter with impact_velocity=%s contact_point=%s" % [name, body.name, impact_velocity, contact_point])
	
	if _shatter_in_progress:
		print_debug("%s: shatter - shatter already in progress - ignoring new shatter event" % name)
		return
	if is_queued_for_deletion():
		print_debug("%s: shatter - ignoring as object already queued for deletion" % name)
		return
	
	# Avoid multi-shot projectiles from triggering a fury of shatter events in a single frame and undefined behavior
	_shatter_in_progress = true
	
	var additional_pieces: Array[Node2D] = await body.shatter_with_velocity(impact_velocity)
	for new_body in additional_pieces:
		_body_container.call_deferred("add_child", new_body)
	
	_delay_shatter_complete()
	
func _delay_shatter_complete() -> void:
	# wait a couple frames - we don't necessarily want to delay a long time as want to destroy the small pieces faster if hit
	# it with a multi-shot weapon
	var process_frame := get_tree().process_frame
	for _i in range(2):
		await process_frame
		
	_on_shatter_cooldown_complete()

func _on_shatter_cooldown_complete() -> void:
	print_debug("%s: Shatter cooldown complete" % name)
	_shatter_in_progress = false
	
func delete() -> void:
	print_debug("ShatterableObject(%s) - delete" % [name])
		
	destroyed.emit(self)

	queue_free.call_deferred()
	
func _on_body_deleted(_body: Node2D) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	if _body_container.get_child_count() == 0:
		delete()

func _to_string() -> String:
	return name
