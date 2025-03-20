class_name DestructibleObjectChunk extends RigidBody2D

@onready var _mesh: Polygon2D = $Mesh
@onready var _collision: CollisionPolygon2D = $Collision
@onready var destructiblePolyOperations = $DestructiblePolyOperations

@export var use_mesh_as_collision:bool = true

@export_category("Smoothing")
@export var smooth_influence_scale: float = 1.5

const surface_delta_y: float = 1.0

func _ready() -> void:
	_sync_polygons()

func damage(projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	owner.damage(self, projectile_poly, poly_scale)


# TODO: Collision will never update if set use_mesh_as_collision to false so maybe remove this option	
func _sync_polygons() -> void:
	if !use_mesh_as_collision:
		return
		
	# Make sure the collision and visual polygon the same
	_collision.set_deferred("position", _mesh.position)
	_collision.set_deferred("polygon", _mesh.polygon)

func _replace_contents_local(new_poly: PackedVector2Array, immediate:bool) -> void:
	
	print_poly("_replace_contents_local", new_poly)

	if(immediate):
		_mesh.polygon = new_poly
	else:
		_mesh.set_deferred("polygon", new_poly)

	_sync_polygons()

class UpdateFlags:
	const Immediate:int = 1
	const Crumble:int = 1 << 1

func replace_contents(new_poly_global: PackedVector2Array, influence_poly_global: PackedVector2Array = [], update_flags:int = UpdateFlags.Crumble) -> Array[PackedVector2Array]:
	print_poly("replace_contents", new_poly_global)

	# Transform updated polygon back to local space
	var destructible_global_inv_transform: Transform2D = _mesh.global_transform.affine_inverse()
	var updated_destructible_poly_local: PackedVector2Array = destructible_global_inv_transform * new_poly_global
	var influence_poly_local: PackedVector2Array = destructible_global_inv_transform * influence_poly_global
	
	# Only apply smoothing and crumbling if given an influence poly
	var replacement_poly_local := updated_destructible_poly_local
	var additional_chunk_polys: Array[PackedVector2Array] = []
	
	if influence_poly_local.size() > 1:
		var bounds:Circle = Circle.create_from_points(influence_poly_local).scale(smooth_influence_scale)
		replacement_poly_local = destructiblePolyOperations.smooth(updated_destructible_poly_local, bounds)
		
		# Now apply crumbling on top and return any new polygons to be added to other chunks if not falling
		if !is_sleeping() and update_flags & UpdateFlags.Crumble:
			var final_polys: Array[PackedVector2Array] = destructiblePolyOperations.crumble(replacement_poly_local, bounds)
			replacement_poly_local = final_polys[0]
			additional_chunk_polys = final_polys.slice(1)
		
	_replace_contents_local(replacement_poly_local, update_flags & UpdateFlags.Immediate)
	
	# Convert additional chunks to global
	for i in range(0, additional_chunk_polys.size()):
		var additional_chunk_poly = additional_chunk_polys[i]
		additional_chunk_polys[i] = _mesh.global_transform * additional_chunk_poly
		
	return additional_chunk_polys

func get_destructible_global() -> PackedVector2Array:
	# Transform terrain polygon to world space
	var destructible_global_transform: Transform2D = _mesh.global_transform
	return destructible_global_transform * _mesh.polygon

func get_destructible_local() -> PackedVector2Array:
	return _mesh.polygon
	
func delete() -> void:
	print("DestructibleObjectChunk(%s) - delete" % [name])
	queue_free.call_deferred()

func print_poly(context: String, poly: PackedVector2Array) -> void:
	if !OS.is_debug_build():
		return
		
	var values: Array[Vector2] = []
	for vector in poly:
		values.push_back(vector)
		
	print_debug("DestructibleObjectChunk(%s) - %s: %d: [%s]"
	 % [name, context, values.size(),
	 ",".join(values.map(func(v : Vector2): return str(v)))])
	
func is_surface_point(vertex: Vector2) -> bool:
	var test_point: Vector2 = vertex + Vector2(0, surface_delta_y)
	return _is_in_terrain(test_point)

func is_surface_point_global(vertex: Vector2) -> bool:
	return contains_point(vertex + Vector2(0, surface_delta_y))

func contains_point(point: Vector2) -> bool:
	var destructible_global_inv_transform: Transform2D = _mesh.global_transform.affine_inverse()
	var point_local := destructible_global_inv_transform * point
	
	return _is_in_terrain(point_local)

func _is_in_terrain(point_local: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point_local, get_destructible_local())

# Sort by largest first
func compare(other: DestructibleObjectChunk) -> bool:
	return _mesh.polygon.size() > other._mesh.polygon.size()
	
func get_bounds_global():
	var bounds:Rect2 = Rect2()
	var viewport_width:float = get_viewport_rect().size.x
	
	for vertex in get_destructible_global():
		# Clamp any negative vertices or those outside the viewport
		vertex.x = clampf(vertex.x, 0.0, viewport_width)
		bounds = bounds.expand(vertex)
	return bounds
