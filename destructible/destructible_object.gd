class_name DestructibleObject extends Node2D

@export_category("Chunk")
@export var chunk_scene: PackedScene

@export_category("Destruction")
@export var crumbling:bool = false

@export_category("Destruction")
@export var create_new_chunks:bool = false

@export_category("Smoothing")
@export var smoothing:bool = true

var initial_chunk_name: String
var first_child_chunk: DestructibleObjectChunk
var chunk_update_flags:int

@onready var _destructible_shape_calculator: DestructibleShapeCalculator = $DestructibleShapeCalculator

func _ready() -> void:
	first_child_chunk = get_first_chunk()
	if !first_child_chunk:
		# Create the first chunk from scene
		first_child_chunk = _add_new_chunk()
	initial_chunk_name = first_child_chunk.name
	
	for chunk in get_children():
		if chunk is DestructibleObjectChunk:
			chunk.owner = self

	if crumbling:
		chunk_update_flags |= DestructibleObjectChunk.UpdateFlags.Crumble
	if smoothing:
		chunk_update_flags |= DestructibleObjectChunk.UpdateFlags.Smooth

func get_first_chunk() -> DestructibleObjectChunk:
	if is_instance_valid(first_child_chunk):
		return first_child_chunk
	for chunk in get_children():
		if chunk is DestructibleObjectChunk:
			first_child_chunk = chunk
			return chunk
	return null

func get_chunk_count() -> int:
	var count:int = 0
	for chunk in get_children():
		if chunk is DestructibleObjectChunk:
			count += 1
	return count

func damage(chunk: DestructibleObjectChunk, projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	print_debug("%s - chunk=%s damaged by %s with poly_scale=%s" % [name, chunk.name, projectile_poly.name, poly_scale])
	
	var projectile_poly_global: PackedVector2Array = _destructible_shape_calculator.get_projectile_poly_global(projectile_poly, poly_scale)
	
	# Transform terrain polygon to world space
	var destructible_poly_global: PackedVector2Array = chunk.get_destructible_global()
	
	# Do clipping operations in global space
	var clipping_results = Geometry2D.clip_polygons(destructible_poly_global, projectile_poly_global)
	
	# This means the chunk was destroyed so we need to queue_free
	if clipping_results.is_empty():
		print("damage(" + name + ") completely destroyed by poly=" + projectile_poly.owner.name)
		chunk.delete()
		return
	
	var updated_destructible_poly = clipping_results[0]
	print("damage(" + name + ") Clip result with " + projectile_poly.owner.name +
	 " - Changing from size of " + str(destructible_poly_global.size()) + " to " + str(updated_destructible_poly.size()))
	
	# This could result in new chunks breaking off
	var destructible_chunk_results := chunk.replace_contents(updated_destructible_poly, projectile_poly_global, chunk_update_flags)
	if !destructible_chunk_results.is_empty():
		_add_new_chunks(get_first_chunk(), destructible_chunk_results, 0)
		
	# We updated the current chunk and no more chunks to add 
	if clipping_results.size() == 1:
		return
		
	_add_new_chunks(get_first_chunk(), clipping_results, 1)


func _add_new_chunks(first_chunk: DestructibleObjectChunk,
 geometry_results: Array[PackedVector2Array], start_index: int) -> void:
	# Create additional chunk pieces for the remaining geometry results
	if !create_new_chunks:
		print("_add_new_chunks(%s) New chunks disabled - ignoring additional %d chunk pieces" % [name, geometry_results.size() - start_index])
		return

	for i in range(start_index, geometry_results.size()):
		var new_clip_poly = geometry_results[i]

		# Ignore clockwise results as these are "holes" and need to handle these differently later
		if TerrainUtils.is_invisible(new_clip_poly):
			print("_add_new_chunks(" + name + ") Ignoring 'hole' polygon for clipping result[" + str(i) + "] of size " + str(new_clip_poly.size()))
			continue
			
		var current_child_count: int = get_chunk_count()		
		var new_chunk_name = initial_chunk_name + str(i + current_child_count)
		
		print("_add_new_chunks(" + name + ") Creating new chunk(" + new_chunk_name + ") for clipping result[" + str(i) + "] of size " + str(new_clip_poly.size()))
		
		# Must be called deferred - see additional comment in _add_new_chunk as to why
		call_deferred("_add_new_chunk", new_chunk_name, new_clip_poly)
	
func _add_new_chunk(chunk_name: String = "", new_clip_poly: PackedVector2Array = []) -> DestructibleObjectChunk:
	if not chunk_scene:
		push_error("%s - No chunk_scene set" % [name])
		return
	var new_chunk = chunk_scene.instantiate()

	if chunk_name:
		new_chunk.name = chunk_name
	
	add_child(new_chunk)
	# Must be done after adding as a child
	new_chunk.owner = self

	# Will be empty if creating the first chunk as using the default values from the chunk_scene
	if new_clip_poly:
		new_chunk.replace_contents(new_clip_poly)

	print_debug("added new chunk=%s - chunk count=%d" % [new_chunk.name, get_chunk_count()])

	return new_chunk

func contains_point(point: Vector2) -> bool:
	for chunk in get_children():
		if chunk is DestructibleObjectChunk:
			if chunk.contains_point(point):
				return true
	return false

func get_chunks() -> Array[DestructibleObjectChunk]:
	var chunks : Array[DestructibleObjectChunk] = []
	for child in get_children():
		if child is DestructibleObjectChunk:
			chunks.push_back(child)
	return chunks
	
func get_bounds_global() -> Rect2:
	var bounds:Rect2 = Rect2()
	
	for chunk in get_chunks():
		bounds = bounds.merge(chunk.get_bounds_global())
	return bounds
