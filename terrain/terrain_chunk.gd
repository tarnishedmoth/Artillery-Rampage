class_name TerrainChunk extends StaticBody2D

class TerrainTexture:
	@export var texture: Texture2D
	@export var material: Material
	@export var repeat: CanvasItem.TextureRepeat = CanvasItem.TextureRepeat.TEXTURE_REPEAT_DISABLED
	@export var offset: Vector2
	
	
@onready var overlap: Area2D = $Overlap
@onready var terrainMesh: Polygon2D = $Polygon2D
@onready var collisionMesh: CollisionPolygon2D = $CollisionPolygon2D
@onready var overlapMesh: CollisionPolygon2D = $Overlap/CollisionPolygon2D
@onready var destructiblePolyOperations: DestructiblePolyOperations = $DestructiblePolyOperations

var terrain: Terrain

# a grass or rock "crust" using a textured Line2D to outline chunk
var outlineMeshEnabled: bool = true
var outlineMesh: Line2D

@export_range(0, 10.0) var gravity_scale:float = 1.0

@export var initially_falling:bool = false

@export var smooth_influence_scale: float = 1.5

@export_group("Textures")
@export var texture_resources: Array[TerrainChunkTextureResource]

const surface_delta_y: float = 1.0

var _can_be_updated:bool = true
var _deferred_update:DeferredPolygonUpdateApplier

var falling:bool = false:
	set(value):
		if value != falling:
			falling = value
			_velocity = Vector2.ZERO
	get:
		return falling
		
var _velocity:Vector2

func _ready() -> void:
	if get_parent() is Terrain: # Should always be true I'm guessing except in precompiler
		terrain = get_parent()
		if terrain.initial_chunk_name.is_empty():
			# We are the first in the scene
			apply_transform_scales_to_polygon2d()
	
	# Make sure the collision and visual polygon the same
	collisionMesh.set_deferred("polygon", terrainMesh.polygon)
	overlapMesh.set_deferred("polygon", terrainMesh.polygon)
	
	if !falling:
		falling = initially_falling
	
	apply_textures()
	
	# a textured line around the outside of the shape (for grass, etc)
	if outlineMeshEnabled :
		init_outline_mesh()
		regenerate_outline_mesh()
	
	print_poly("_ready", collisionMesh.polygon)
	
## Move vertices using xform.scale as a multiplier to correct for use in editor.
func apply_transform_scales_to_polygon2d() -> void:
	#  Gather all the relevant transforms from Terrain downward and multiply them together
	var total_scale: Vector2 = Vector2.ONE
	#  Add up our scales
	total_scale *= terrain.transform.get_scale()
	total_scale *= self.transform.get_scale()
	total_scale *= terrainMesh.transform.get_scale()
	#  Reset our nodes' scales
	terrain.set_scale(Vector2.ONE)
	self.set_scale(Vector2.ONE)
	terrainMesh.set_scale(Vector2.ONE)
		
	if total_scale != Vector2.ONE:
		# Make a copy of our polygon data
		var vertices:PackedVector2Array = terrainMesh.polygon.duplicate() # This returns a copy
		# Not sure why you can't do "for vertex in vertices: vertex *= foo", but that doesn't modify the item. Shrug
		for i in vertices.size():
			# Apply the scale to the vertex position
			vertices[i] *= total_scale
		
		# Apply our new polygon to the Polygon2D
		terrainMesh.set_polygon(vertices)
		print_debug("Corrected terrain scale of ", total_scale)
	
	# and make sure the outline matches the adjusted verts
	regenerate_outline_mesh()

	
func apply_textures() -> void:
	# give the terrain a texture like rock or grass
	# idea: we could load multiple textures!
	# maybe texture chosen by chunk size (big=grass, small=blackened)
	# maybe texture chosen by by altitude (rock->grass->mud->lava)
	
	# These are now set via the texture_resources array above
	# We could add additional properties to the resource to describe matching criteria and then determine 
	# matches or "best fit" via a script function on terrain_chunk_texture.gd
	#var tex = load("res://terrain/terrain-strata.png")
	#terrainMesh.set_texture(tex)
	## terrainMesh.texture_repeat = TextureRepeat.TEXTURE_REPEAT_ENABLED
	#terrainMesh.texture_repeat = TextureRepeat.TEXTURE_REPEAT_MIRROR
	#terrainMesh.texture_offset = Vector2(0,400)
	
	for resource in texture_resources:
		if resource.matches(self):
			resource.apply_to(self)
			break
			
	
func init_outline_mesh() -> void:
	if !outlineMeshEnabled : return
	if outlineMesh != null : return
	outlineMesh = Line2D.new()
	outlineMesh.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	outlineMesh.texture_mode = Line2D.LINE_TEXTURE_TILE
	outlineMesh.closed = true

	# FIXME:
	# none of these corner styles look right: 
	# "obtuse angles" will stretch the texture badly
	# to fix, we may need to add more points to the curve?
	outlineMesh.joint_mode = Line2D.LINE_JOINT_SHARP # _BEVEL _SHARP _ROUND
	outlineMesh.width = 64

	# is there a second entry in resources set in the editor?
	if texture_resources.size() > 1 :
		outlineMesh.set_texture(texture_resources[1].texture)
	else: # load a default
		outlineMesh.set_texture(load("res://terrain/terrain-outline-grass.png"))
	# as a child of this chunk so it moves too:
	add_child(outlineMesh)
	
func regenerate_outline_mesh() -> void:
	if !outlineMeshEnabled : return
	if outlineMesh == null : init_outline_mesh()
	
	# the slow way:
	# outlineMesh.clear_points()
	# for i in terrainMesh.polygon.size():
	# 	outlineMesh.add_point(terrainMesh.polygon[i])
	
	# the faster yet safe way
	# outlineMesh.points = terrainMesh.polygon.duplicate()
	
	# the very fast but DANGEROUS way
	outlineMesh.points = terrainMesh.polygon
	
	
func _physics_process(delta: float) -> void:
	if !falling: return
	
	# Check for overlaps with other chunks and stop falling if so
	var overlaps = overlap.get_overlapping_areas()
	var handled_merge:bool = false
	
	for _overlap in overlaps:
		if _overlap.collision_layer == Collisions.Layers.terrain and not handled_merge:
			handled_merge = true
			# Also stop falling if merge said we shouldn't but we are the bigger chunk
			if owner.merge_chunks(_overlap.get_parent(), self) or self.get_bounds_global().get_area() > _overlap.get_parent().get_bounds_global().get_area():
				falling = false
				return
		elif _overlap.collision_layer == Collisions.Layers.floor:
			print_debug("TerrainChunk(%s) - stop falling as hit the floor: %s" % [name, _overlap.get_parent().name])
			falling = false
			return
			
	_velocity += PhysicsUtils.get_gravity_vector() * gravity_scale * delta
	global_position += _velocity * delta

func _replace_contents_local(new_poly: PackedVector2Array, immediate:bool) -> void:
	print_poly("_replace_contents_local", new_poly)

	var deferred_updates: Array[Node] = []

	if(immediate):
		terrainMesh.polygon = new_poly
	else:
		deferred_updates.push_back(terrainMesh)

	deferred_updates.push_back(collisionMesh)
	deferred_updates.push_back(overlapMesh)	

	_set_polygon_deferred(deferred_updates, new_poly)

func _set_polygon_deferred(polygon_nodes: Array[Node], new_poly: PackedVector2Array) -> void:
	# Cancel previous requested update by overwriting it which will free the previous ref counted instance and cancel any pending cals
	_deferred_update = DeferredPolygonUpdateApplier.new(self, polygon_nodes, new_poly)
	_deferred_update.apply()

class DeferredPolygonUpdateApplier:
	var is_applied:bool
	var parent:TerrainChunk
	var polygon_nodes: Array[Node]
	var new_poly: PackedVector2Array

	func _init(in_parent:TerrainChunk, in_polygon_nodes: Array[Node], in_new_poly: PackedVector2Array):
		self.parent = in_parent
		self.polygon_nodes = in_polygon_nodes
		self.new_poly = in_new_poly

	func apply() -> void:
		parent._can_be_updated = false
		_do_apply.call_deferred()
	
	func _do_apply() -> void:
		for node in polygon_nodes:
			node.polygon = new_poly
		
		if parent.outlineMeshEnabled: 
			parent.regenerate_outline_mesh()

		parent._can_be_updated = true
		is_applied = true

class UpdateFlags:
	const Immediate:int = 1
	const Crumble:int = 1 << 1

func replace_contents(new_poly_global: PackedVector2Array, influence_poly_global: PackedVector2Array = [], update_flags:int = UpdateFlags.Crumble) -> Array[PackedVector2Array]:
	print_poly("replace_contents", new_poly_global)

	# Transform updated polygon back to local space
	var terrain_global_inv_transform: Transform2D = terrainMesh.global_transform.affine_inverse()
	var updated_terrain_poly_local: PackedVector2Array = terrain_global_inv_transform * new_poly_global
	var influence_poly_local: PackedVector2Array = terrain_global_inv_transform * influence_poly_global
	
	# Only apply smoothing and crumbling if given an influence poly
	var replacement_poly_local := updated_terrain_poly_local
	var additional_chunk_polys: Array[PackedVector2Array] = []
	
	if influence_poly_local.size() > 1:
		var bounds:Circle = Circle.create_from_points(influence_poly_local).scale(smooth_influence_scale)
		replacement_poly_local = destructiblePolyOperations.smooth(updated_terrain_poly_local, bounds)
		
		# Now apply crumbling on top and return any new polygons to be added to other chunks if not falling
		if !falling and update_flags & UpdateFlags.Crumble:
			var final_polys: Array[PackedVector2Array] = destructiblePolyOperations.crumble(replacement_poly_local, bounds)
			replacement_poly_local = final_polys[0]
			additional_chunk_polys = final_polys.slice(1)
		
	_replace_contents_local(replacement_poly_local, update_flags & UpdateFlags.Immediate)
	
	# Convert additional chunks to global
	for i in range(0, additional_chunk_polys.size()):
		var additional_chunk_poly = additional_chunk_polys[i]
		additional_chunk_polys[i] = terrainMesh.global_transform * additional_chunk_poly
		
	return additional_chunk_polys

func get_terrain_global() -> PackedVector2Array:
	# Transform terrain polygon to world space
	var terrain_global_transform: Transform2D = terrainMesh.global_transform
	return terrain_global_transform * get_terrain_local()

func get_terrain_local() -> PackedVector2Array:
	# Return pending update poly if it exists
	if _deferred_update:
		if not _deferred_update.is_applied:
			return _deferred_update.new_poly
		else:
			# Free memory lazily for completed state
			_deferred_update = null
	return terrainMesh.polygon
	
func delete() -> void:
	print("TerrainChunk(%s) - delete" % [name])
	_can_be_updated = false
	queue_free.call_deferred()
	
# Based on https://www.youtube.com/watch?v=FiKsyOLacwA
# poly_scale will determine the size of the explosion that destroys the terrain
func damage(projectile: WeaponProjectile, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	if not _can_be_updated:
		print_debug("%s: damage - damage already in progress - ignoring new damage event" % name)
		return
		
	owner.damage(self, projectile, contact_point, poly_scale)

func is_surface_point(vertex: Vector2) -> bool:
	var test_point: Vector2 = vertex + Vector2(0, surface_delta_y)
	return _is_in_terrain(test_point)

func is_surface_point_global(vertex: Vector2) -> bool:
	return contains_point(vertex + Vector2(0, surface_delta_y))

func contains_point(point: Vector2) -> bool:
	var terrain_global_inv_transform: Transform2D = terrainMesh.global_transform.affine_inverse()
	var point_local := terrain_global_inv_transform * point
	
	return _is_in_terrain(point_local)

func _is_in_terrain(point_local: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point_local, get_terrain_local())

func get_area() -> float:
	return TerrainUtils.calculate_polygon_area(get_terrain_local())

# Sort by largest first
func compare(other: TerrainChunk) -> bool:
	return get_terrain_local().size() > other.get_terrain_local().size()
	
func print_poly(context: String, poly: PackedVector2Array) -> void:
	if !OS.is_debug_build():
		return

	return TerrainUtils.print_poly("TerrainChunk(%s) - %s" % [name, context], poly)
	
func get_bounds_global():
	var bounds:Rect2 = Rect2()
	var viewport_width:float = get_viewport_rect().size.x
	
	for vertex in get_terrain_global():
		# Clamp any negative vertices or those outside the viewport
		vertex.x = clampf(vertex.x, 0.0, viewport_width)
		bounds = bounds.expand(vertex)
	return bounds

func _to_string() -> String:
	return name
