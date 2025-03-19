class_name DestructibleObject extends RigidBody2D

@onready var _mesh: Polygon2D = $Mesh
@onready var _collision: CollisionPolygon2D = $Collision

@export var use_mesh_as_collision:bool = true

func _ready() -> void:
	_sync_polygons()

func damage(projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	print_debug("%s - damaged by %s with poly_scale=%s" % [self, projectile_poly, poly_scale])
	
func _sync_polygons() -> void:
	if !use_mesh_as_collision:
		return
		
	# Make sure the collision and visual polygon the same
	_collision.set_deferred("position", _mesh.position)
	_collision.set_deferred("polygon", _mesh.polygon)
