class_name ShatterableObjectBody extends RigidBody2D

@onready var _mesh: Polygon2D = $Mesh
@onready var _collision: CollisionPolygon2D = $Collision

@export var use_mesh_as_collision:bool = true

func _ready() -> void:
	if use_mesh_as_collision:
		_collision.set_deferred("position", _mesh.position)
		_collision.set_deferred("polygon", _mesh.polygon)

func damage(projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	owner.damage(self, projectile_poly, poly_scale)
	
func shatter(destructible_poly_global: PackedVector2Array) -> Array[Node2D]:
	# TODO: Split current polygon into smaller pieces as new bodies
	# Should set a lifetime on smaller pieces to auto-delete or go to sleep permanently after a given interval
	# If we want ot be able to shatter again we return another instance of ShatterableObjectBody; otherwise, return a simple RigidBody2D or event a 
	# StaticBody2D or just a particle effect that expires and deletes itself after a period
	delete()
	return []

func delete() -> void:
	print("ShatterableObjectBody(%s) - delete" % [name])
	owner.body_deleted.emit(self)
	
	queue_free.call_deferred()
