class_name ShatterableObject extends Node2D

@onready var _destructible_shape_calculator: DestructibleShapeCalculator = $DestructibleShapeCalculator
@onready var _body_container:Node = $BodyContainer
@onready var _shatter_completion_timer:Timer = $ShatterCompletionTimer

var _shatter_in_progress:bool = false

@warning_ignore("unused_signal")
signal destroyed(object: ShatterableObject)

@warning_ignore("unused_signal")
signal body_deleted(body: Node2D)

func _ready() -> void:
	body_deleted.connect(_on_body_deleted)
	_shatter_completion_timer.timeout.connect(_on_shatter_cooldown_complete)
	
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
	
	var additional_pieces: Array[Node2D] = body.shatter(projectile, projectile_poly_global)
	for new_body in additional_pieces:
		_body_container.call_deferred("add_child", new_body)
	
	_delay_shatter_complete()
	
func _delay_shatter_complete() -> void:
	# _shatter_completion_timer.start()
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
	
	_shatter_completion_timer.stop()
	
	destroyed.emit(self)

	queue_free.call_deferred()
	
func _on_body_deleted(_body: Node2D) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	if _body_container.get_child_count() == 0:
		delete()
