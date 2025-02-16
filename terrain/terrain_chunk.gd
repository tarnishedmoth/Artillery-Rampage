class_name TerrainChunk extends StaticBody2D

@onready var overlap = $Overlap
@onready var terrainMesh = $Polygon2D
@onready var collisionMesh = $CollisionPolygon2D
@onready var overlapMesh = $Overlap/CollisionPolygon2D

func _ready() -> void:
	# Make sure the collision and visual polygon the same
	collisionMesh.polygon = terrainMesh.polygon

func _replace_contents_local(new_poly: PackedVector2Array) -> void:
	terrainMesh.set_deferred("polygon", new_poly)
	collisionMesh.set_deferred("polygon", new_poly)
	overlapMesh.set_deferred("polygon", new_poly)

func replace_contents(new_poly_global: PackedVector2Array) -> void:
	# Transform updated polygon back to local space
	var terrain_global_inv_transform: Transform2D = terrainMesh.global_transform.affine_inverse()
	var updated_terrain_poly_local: PackedVector2Array = terrain_global_inv_transform * new_poly_global
	
	_replace_contents_local(updated_terrain_poly_local)

func get_terrain_global() -> PackedVector2Array:
	# Transform terrain polygon to world space
	var terrain_global_transform: Transform2D = terrainMesh.global_transform
	return terrain_global_transform * terrainMesh.polygon

# Based on https://www.youtube.com/watch?v=FiKsyOLacwA
# poly_scale will determine the size of the explosion that destroys the terrain
func damage(projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	owner.damage(self, projectile_poly, poly_scale)
	
func print_poly(poly: PackedVector2Array):
	for i in range(poly.size()):
		print("poly[" + str(i) + "]=" + str(poly[i]))
