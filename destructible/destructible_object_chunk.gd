class_name DestructibleObjectChunk extends RigidBody2D

@onready var _mesh: Polygon2D = $Mesh
@onready var _collision: CollisionPolygon2D = $Collision
@onready var destructiblePolyOperations = $DestructiblePolyOperations

@export var use_mesh_as_collision:bool = true

@export_category("Smoothing")
@export var smooth_influence_scale: float = 1.5

## Whether to reduce the mass of the chunk as it is damaged per initial calculated density
@export_group("Damage")
@export var reduce_mass_on_damage: bool = true

## Minimum mass to allow to avoid physics instability
@export_group("Damage")
@export var min_mass: float

@export_group("Damage")
@export var destroy_below_min_mass: bool

@export_group("Physical Properties")
@export
## Density in kg / p^2
var density: float

const surface_delta_y: float = 1.0

var _collision_dirty:bool
var _initialized_mass_and_density:bool

func _ready() -> void:
	if not _mesh.polygon.is_empty():
		_set_initial_mass_and_density()
		_request_sync_polygons()

func damage(projectile: WeaponProjectile, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	owner.damage(self, projectile, contact_point, poly_scale)

# TODO: Collision will never update if set use_mesh_as_collision to false so maybe remove this option	
func _request_sync_polygons() -> void:
	if !use_mesh_as_collision:
		return
	# Make sure the collision and visual polygon the same
	# Need to wake up the rigid body if it is asleep so that these changes take immediate effect
	sleeping = false
	
	# Wait until next frame to signal the collision update
	await get_tree().physics_frame
	_collision_dirty = true

func _sync_polygons() -> void:
	_collision.position = _mesh.position
	
	# Still need to defer this even in _integrate_forces to avoid errors
	# Doesn't appear to introduce any new lag between mesh shape and collision shape in gameplay
	_collision.set_deferred("polygon", _mesh.polygon)
	
	if reduce_mass_on_damage:
		_recalculate_mass()

	_collision_dirty = false

func _set_initial_mass_and_density() -> void:
	_initialized_mass_and_density = true

	# If density already provided, set the mass based on density and area
	if density > 0:
		_recalculate_mass()
	elif mass > 0:
		_calculate_density()
	else:
		push_warning("DestructibleObjectChunk(%s) - Neither mass nor density provided, setting density to 1.0" % [name])
		density = 1.0
		_recalculate_mass()
	
func _recalculate_mass() -> void:
	if not _initialized_mass_and_density:
		_set_initial_mass_and_density()
		return
	
	# Calculate the mass based on the area of the polygon
	var should_delete:bool = false
	var area:float = get_area()
	
	if is_zero_approx(area):
		push_warning("DestructibleObjectChunk(%s) - Polygon area is zero" % [name])
		mass = min_mass
		should_delete = destroy_below_min_mass
	else:
		var new_mass := area * density
		if new_mass < min_mass:
			new_mass = min_mass
			should_delete = destroy_below_min_mass
		mass = new_mass
		
	print_debug("DestructibleObjectChunk(%s) - mass=%f; density=%f" % [name, mass, density])
	
	if should_delete:
		owner.delete_chunk(self)

func _calculate_density() -> void:
	# Calculate the density based on the mass and area of the polygon
	var area:float = get_area()
	if is_zero_approx(area):
		push_warning("DestructibleObjectChunk(%s) - Polygon area is zero, setting density to 1" % [name])
		density = 1
	else:
		density = mass / area

	print_debug("DestructibleObjectChunk(%s) - mass=%f; density=%f" % [name, mass, density])

func get_area() -> float:
	return TerrainUtils.calculate_polygon_area(_mesh.polygon)

func get_rect() -> Rect2:
	var bounds:Rect2 = TerrainUtils.get_polygon_bounds(_mesh.polygon)
	bounds.position += to_local(_mesh.global_position)
	return bounds
	
func _integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	# If the collision polygon is dirty, update the collision polygon
	if _collision_dirty:
		_sync_polygons()

func _replace_contents_local(new_poly: PackedVector2Array, immediate:bool) -> void:
	print_poly("_replace_contents_local", new_poly)

	# Delete ourselves if we aren't visible
	if TerrainUtils.is_invisible_polygon(new_poly):
		owner.delete_chunk(self)
		return
	
	if(immediate):
		_update_poly_local(new_poly)
	else:
		call_deferred("_update_poly_local", new_poly)

	_request_sync_polygons()

## Called to update the meshes polygon in local space
## Can be overridden to take additional actions
func _update_poly_local(new_poly: PackedVector2Array) -> void:
	_mesh.polygon = new_poly

class UpdateFlags:
	const Immediate:int = 1
	const Crumble:int = 1 << 1
	const Smooth:int = 1 << 2

func replace_contents(new_poly_global: PackedVector2Array, influence_poly_global: PackedVector2Array = [], update_flags:int = UpdateFlags.Crumble | UpdateFlags.Smooth) -> Array[PackedVector2Array]:
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

		if update_flags & UpdateFlags.Smooth:
			replacement_poly_local = destructiblePolyOperations.smooth(updated_destructible_poly_local, bounds)
		
		# Now apply crumbling on top and return any new polygons to be added to other chunks if not falling
		if !is_sleeping() and update_flags & UpdateFlags.Crumble:
			var final_polys: Array[PackedVector2Array] = destructiblePolyOperations.crumble(replacement_poly_local, bounds)
			replacement_poly_local = final_polys[0]
			additional_chunk_polys = final_polys.slice(1)
		
	_replace_contents_local(replacement_poly_local, update_flags & UpdateFlags.Immediate)
	
	# Convert additional chunks to global
	for i in additional_chunk_polys.size():
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
	print_debug("DestructibleObjectChunk(%s) - delete" % [name])
	queue_free.call_deferred()

func print_poly(context: String, poly: PackedVector2Array) -> void:
	if !OS.is_debug_build():
		return
		
	return TerrainUtils.print_poly("DestructibleObjectChunk(%s) - %s" % [name, context], poly)
	
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

func _to_string() -> String:
	return name
