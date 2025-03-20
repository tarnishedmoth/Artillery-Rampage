class_name DestructibleShapeCalculator extends Node

@export_category("Projectile")
@export var min_damage_shape_offset: float = 0

@export_category("Projectile")
@export var max_damage_shape_offset: float = 1

@export_category("Projectile")
@export var damage_scale_failure_reduction_step: float = 10.0

func get_projectile_poly_global( projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1, 1)) -> PackedVector2Array:
	var scale_transform: Transform2D = Transform2D(0, poly_scale, 0, Vector2())
	# Combine the scale transform with the world (global) transform
	var combined_transform: Transform2D = projectile_poly.global_transform * scale_transform
	
	var projectile_poly_global: PackedVector2Array = combined_transform * projectile_poly.polygon
	
	_randomize_damage_polygon(projectile_poly_global, poly_scale)
	
	return projectile_poly_global

func _randomize_damage_polygon(projectile_damage_global: PackedVector2Array, poly_scale: Vector2) -> void:
	var poly_scale_size: float = poly_scale.length()
	
	var projectile_damage_test_polygon: PackedVector2Array
	projectile_damage_test_polygon.resize(projectile_damage_global.size())

	var scale_decrements: float = poly_scale_size / damage_scale_failure_reduction_step
	var success:bool = false

	var scale_value: float = poly_scale_size
	while scale_value > 0:
		for i in range(0, projectile_damage_global.size()):
			projectile_damage_test_polygon[i] = projectile_damage_global[i] + _get_offset_damage_poly_vertex(scale_value)
		
		if TerrainUtils._is_visible_polygon(projectile_damage_test_polygon):
			success = true
			break
		else:
			scale_value -= scale_decrements
			print_debug("%s: Created non-viable damage result with damage polygon of size %d, trying again and reducing scale to %f" % [name, projectile_damage_test_polygon.size(), scale_value])

	if success:
		# copy the test polygon changes over to the original
		for i in range(0, projectile_damage_global.size()):
			projectile_damage_global[i] = projectile_damage_test_polygon[i]
	else:
		push_warning("%s: Unable to create a viable damage polygon after %d attempts - removing randomization" % [name, ceili(poly_scale_size / scale_decrements)])
		# Will use the default polygon vertices passed in that are already scaled

func _get_offset_damage_poly_vertex(scale_value: float) -> Vector2:
	return Vector2(0, _get_random_damage_offset(scale_value))
	
func _get_random_damage_offset(scale_value: float) -> float:
	return randf_range(min_damage_shape_offset * scale_value, max_damage_shape_offset * scale_value) * (1 if randf() >= 0.5 else -1)
