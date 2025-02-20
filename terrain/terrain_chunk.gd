class_name TerrainChunk extends StaticBody2D

@onready var overlap = $Overlap
@onready var terrainMesh = $Polygon2D
@onready var collisionMesh = $CollisionPolygon2D
@onready var overlapMesh = $Overlap/CollisionPolygon2D

@export var gravity:float = 9.8

@export var smooth_y_threshold_pct: float = 0.5

# Sometimes the algorithm flags things incorrectly that are essentially vertical drops near the left of screen
@export var smooth_x_threshold_diff: float = 10

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
	collisionMesh.polygon = terrainMesh.polygon
	
	print_poly("_ready", collisionMesh.polygon)
	
func _physics_process(delta: float) -> void:
	if !falling: return
	
	# Check for overlaps with other chunks and stop falling if so
	var overlaps = overlap.get_overlapping_areas()
	for overlap in overlaps:
		if overlap.collision_layer == Collisions.Layers.terrain:
			owner.merge_chunks(overlap.get_parent(), self)
			falling = false
			return

	_velocity += Vector2(0, gravity) * delta
	global_position += _velocity * delta
	
func _replace_contents_local(new_poly: PackedVector2Array) -> void:
	
	print_poly("_replace_contents_local", new_poly)

	terrainMesh.set_deferred("polygon", new_poly)
	collisionMesh.set_deferred("polygon", new_poly)
	overlapMesh.set_deferred("polygon", new_poly)

func _smooth() -> bool:
	var poly: PackedVector2Array = get_terrain_local()
	
	# Polygon is actually stored clockwise. Look at vertices and see where x decreases indicating a dent until we start winding around
	# Don't modify the interior of the terrain. Detect this by looking at the maximum y (bottom-most point)
	var bottom_y: float = -1e12
	var top_y: float = 1e12
	for vec in poly:
		if vec.y > bottom_y : bottom_y = vec.y
		elif vec.y < top_y : top_y = vec.y
	var threshold_y: float = (bottom_y - top_y) * smooth_y_threshold_pct + bottom_y
	
	var smooth_updates: int = 0
	
	for i in range(1, poly.size()):
		var current := poly[i]
		var prev := poly[i - 1]

		# Don't modify the bottom
		if current.x - prev.x < -smooth_x_threshold_diff and current.y < prev.y and current.y < threshold_y:
			poly[i] = (prev + current) * 0.5
			smooth_updates += 1
	#		if i > 1 and absf(poly[i - 1].y - bottom_y) > smooth_y_threshold_value:
	#			poly[i - 1] = (prev + poly[i - 2]) * 0.5
	#			smooth_updates += 1
	
	if smooth_updates:
		print("TerrainChunk(%s) - _smooth: Changed %d verticies" % [name, smooth_updates])
		_replace_contents_local(poly)
		
	return smooth_updates
		
func replace_contents(new_poly_global: PackedVector2Array) -> void:
	
	print_poly("replace_contents", new_poly_global)

	# Transform updated polygon back to local space
	var terrain_global_inv_transform: Transform2D = terrainMesh.global_transform.affine_inverse()
	var updated_terrain_poly_local: PackedVector2Array = terrain_global_inv_transform * new_poly_global
	
	if !_smooth():
		_replace_contents_local(updated_terrain_poly_local)

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
func damage(projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	owner.damage(self, projectile_poly, poly_scale)
	
# Sort by largest first
func compare(other: TerrainChunk) -> bool:
	return terrainMesh.polygon.size() > other.terrainMesh.polygon.size()
	
func print_poly(context: String, poly: PackedVector2Array) -> void:
	var values: Array[Vector2] = []
	for vector in poly:
		values.push_back(vector)
		
	print("TerrainChunk(%s) - %s: %d: [%s]"
	 % [name, context, values.size(),
	 ",".join(values.map(func(v : Vector2): return str(v)))])
	#for i in range(poly.size()):
		#print("poly[" + str(i) + "]=" + str(poly[i]))
