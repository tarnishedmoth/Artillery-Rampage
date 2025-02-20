class_name TerrainChunk extends StaticBody2D

@onready var overlap = $Overlap
@onready var terrainMesh = $Polygon2D
@onready var collisionMesh = $CollisionPolygon2D
@onready var overlapMesh = $Overlap/CollisionPolygon2D

@export var gravity:float = 9.8

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

func replace_contents(new_poly_global: PackedVector2Array) -> void:
	
	print_poly("replace_contents", new_poly_global)

	# Transform updated polygon back to local space
	var terrain_global_inv_transform: Transform2D = terrainMesh.global_transform.affine_inverse()
	var updated_terrain_poly_local: PackedVector2Array = terrain_global_inv_transform * new_poly_global
	
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
