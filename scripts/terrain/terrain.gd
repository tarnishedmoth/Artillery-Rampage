class_name Terrain extends Node2D

@onready var overlap = $StaticBody2D/Overlap
@onready var terrainMesh = $StaticBody2D/Polygon2D
@onready var collisionMesh = $StaticBody2D/CollisionPolygon2D
@onready var overlapMesh = $StaticBody2D/Overlap/CollisionPolygon2D

func _ready() -> void:
	overlap.connect("area_entered", on_area_entered)
	# Make sure the collision and visual polygon the same
	collisionMesh.polygon = terrainMesh.polygon

func on_area_entered(area: Area2D):
	if area.owner is WeaponProjectile:
		# Destroy
		area.owner.destroy()

# Based on https://www.youtube.com/watch?v=FiKsyOLacwA
# poly_scale will determine the size of the explosion that destroys the terrain
func damage(projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):

	#print("Clipping terrain with polygon:", projectile_poly.polygon)
	var scale_transform: Transform2D = Transform2D(0, poly_scale, 0, Vector2())
	# Combine the scale transform with the world (global) transform
	var combined_transform: Transform2D = projectile_poly.global_transform * scale_transform
	
	var projectile_poly_global: PackedVector2Array = combined_transform * projectile_poly.polygon

	#print("clip - input poly")
	#print_poly(projectile_poly_global)
	
	# Transform terrain polygon to world space
	var terrain_global_transform: Transform2D = terrainMesh.global_transform
	var terrain_poly_global: PackedVector2Array = terrain_global_transform * terrainMesh.polygon

	#print("clip - terrain poly in world space")
	#print_poly(terrain_poly_global)
	
	# Do clipping operations in global space
	var clipping_result = Geometry2D.clip_polygons(terrain_poly_global, projectile_poly_global)
	
	if clipping_result.is_empty():
		print("clip: No terrain clipping from poly=" + projectile_poly.owner.name)
		return
	
	# Main clipped polygon
	# If we want to represent "islands" we'd need to add a new polygon2D node
	# to represent it which means adding a new child for each one beyond 1
	var updated_terrain_poly = clipping_result[0]
	print("clip: Clip result with " + projectile_poly.owner.name +
	 " - Changing from size of " + str(terrainMesh.polygon.size()) + " to " + str(updated_terrain_poly.size()))

	#print("old poly (WORLD):")
	#print_poly(terrain_poly_global)
	#print("new poly (WORLD):")
	#print_poly(updated_terrain_poly)
	
	# Transform updated polygon back to local space
	var terrain_global_inv_transform: Transform2D = terrain_global_transform.affine_inverse()
	var updated_terrain_poly_local: PackedVector2Array = terrain_global_inv_transform * updated_terrain_poly
	
	#print("old poly (LOCAL):")
	#print_poly(terrainMesh.polygon)
	#print("new poly (LOCAL):")
	#print_poly(updated_terrain_poly_local)
	
	terrainMesh.set_deferred("polygon", updated_terrain_poly_local)
	collisionMesh.set_deferred("polygon", updated_terrain_poly_local)
	overlapMesh.set_deferred("polygon", updated_terrain_poly_local)
	
func print_poly(poly: PackedVector2Array):
	for i in range(poly.size()):
		print("poly[" + str(i) + "]=" + str(poly[i]))
