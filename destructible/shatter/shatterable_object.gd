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
	
func damage(body: ShatterableObjectBody, projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	print_debug("%s - body=%s damaged by %s with poly_scale=%s" % [name, body.name, projectile_poly.name, poly_scale])
	
	# TODO: Cache this for given frame and event
	var projectile_poly_global: PackedVector2Array = _destructible_shape_calculator.get_projectile_poly_global(projectile_poly, poly_scale)
	
	#var additional_pieces: Array[Node2D] = []
	#for body in _body_container.get_children():
		#if is_instance_valid(body) and body is ShatterableObjectBody:
			#additional_pieces.append_array(body.shatter(self, destructible_poly_global))
	
	var additional_pieces: Array[Node2D] = body.shatter(projectile_poly_global)
	for new_body in additional_pieces:
		_body_container.add_child(new_body)
		
	# TODO: Maybe apply a physics force to remaining bodies close to the projectile_poly_global that weren't directly damaged

	
func delete() -> void:
	print("ShatterableObject(%s) - delete" % [name])
	destroyed.emit(self)

	queue_free.call_deferred()
	
func _on_body_deleted(_body: Node2D) -> void:
	await get_tree().process_frame
	
	if _body_container.get_child_count() == 0:
		delete()
