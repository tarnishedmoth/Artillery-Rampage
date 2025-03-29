class_name TerrainChunk extends StaticBody2D

class TerrainTexture:
	@export var texture: Texture2D
	@export var repeat: CanvasItem.TextureRepeat = CanvasItem.TextureRepeat.TEXTURE_REPEAT_DISABLED
	@export var offset: Vector2
	
	
@onready var overlap = $Overlap
@onready var terrainMesh = $Polygon2D
@onready var collisionMesh = $CollisionPolygon2D
@onready var overlapMesh = $Overlap/CollisionPolygon2D
@onready var destructiblePolyOperations = $DestructiblePolyOperations

@export_range(0, 1000) var gravity:float = 20
@export var initially_falling:bool = false

@export var smooth_influence_scale: float = 1.5

@export_group("Textures")
@export var texture_resources: Array[TerrainChunkTextureResource]

const surface_delta_y: float = 1.0

var falling:bool = false:
	set(value):
		if value != falling:
			falling = value
			_velocity = Vector2.ZERO
	get:
		return falling
		
var _velocity:Vector2

func _ready() -> void:
	# Make sure the collision and visual polygon the same
	collisionMesh.set_deferred("polygon", terrainMesh.polygon)
	overlapMesh.set_deferred("polygon", terrainMesh.polygon)
	
	if !falling:
		falling = initially_falling
	
	_apply_textures()
	
	print_poly("_ready", collisionMesh.polygon)
	
func _apply_textures() -> void:
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
			
	_velocity += Vector2(0, gravity) * delta
	global_position += _velocity * delta

func _replace_contents_local(new_poly: PackedVector2Array, immediate:bool) -> void:
	
	print_poly("_replace_contents_local", new_poly)

	if(immediate):
		terrainMesh.polygon = new_poly
	else:
		terrainMesh.set_deferred("polygon", new_poly)
	collisionMesh.set_deferred("polygon", new_poly)
	overlapMesh.set_deferred("polygon", new_poly)

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
	return terrain_global_transform * terrainMesh.polygon

func get_terrain_local() -> PackedVector2Array:
	return terrainMesh.polygon
	
func delete() -> void:
	print("TerrainChunk(%s) - delete" % [name])
	queue_free.call_deferred()
	
# Based on https://www.youtube.com/watch?v=FiKsyOLacwA
# poly_scale will determine the size of the explosion that destroys the terrain
func damage(projectile: WeaponProjectile, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
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

# Sort by largest first
func compare(other: TerrainChunk) -> bool:
	return terrainMesh.polygon.size() > other.terrainMesh.polygon.size()
	
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
