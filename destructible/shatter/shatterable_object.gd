class_name ShatterableObject extends Node2D

@onready var _destructible_shape_calculator: DestructibleShapeCalculator = $DestructibleShapeCalculator
@onready var _body_container:Node = $BodyContainer

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
	
	# TODO: Cache this for given frame and event
	var projectile_poly: CollisionPolygon2D = projectile.get_destructible_component()
	var projectile_poly_global: PackedVector2Array = _destructible_shape_calculator.get_projectile_poly_global(projectile_poly, poly_scale)
	
	var additional_pieces: Array[Node2D] = body.shatter(projectile, projectile_poly_global)
	for new_body in additional_pieces:
		_body_container.call_deferred("add_child", new_body)
			
func delete() -> void:
	print_debug("ShatterableObject(%s) - delete" % [name])
	destroyed.emit(self)

	queue_free.call_deferred()
	
func _on_body_deleted(_body: Node2D) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	if _body_container.get_child_count() == 0:
		delete()
