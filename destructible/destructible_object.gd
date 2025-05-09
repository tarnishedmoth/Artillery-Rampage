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
var chunk_update_flags:int

@warning_ignore("unused_signal")
signal chunk_split(chunk: DestructibleObjectChunk,  new_chunk: DestructibleObjectChunk)

@warning_ignore("unused_signal")
signal destroyed(object: DestructibleObject)

@warning_ignore("unused_signal")
signal chunk_destroyed(object: DestructibleObjectChunk)

@onready var _destructible_shape_calculator: DestructibleShapeCalculator = $DestructibleShapeCalculator

func _ready() -> void:
	var initial_chunks := get_chunks()
	if !initial_chunks:
		# Create the first chunk from scene
		initial_chunks.push_back(_add_new_chunk())

	initial_chunk_name = initial_chunks[0].name
	
	for chunk in initial_chunks:
		chunk.owner = self

	if crumbling:
		chunk_update_flags |= DestructibleObjectChunk.UpdateFlags.Crumble
	if smoothing:
		chunk_update_flags |= DestructibleObjectChunk.UpdateFlags.Smooth

func get_chunk_count() -> int:
	var count:int = 0
	for chunk in get_children():
		if chunk is DestructibleObjectChunk:
			count += 1
	return count

@warning_ignore("unused_parameter")
func damage(chunk: DestructibleObjectChunk, projectile: WeaponProjectile, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	print_debug("%s - chunk=%s damaged by %s with poly_scale=%s" % [name, chunk.name, projectile.name, poly_scale])
	
	var projectile_poly: CollisionPolygon2D = projectile.get_destructible_component()
	var projectile_poly_global: PackedVector2Array = _destructible_shape_calculator.get_projectile_poly_global(projectile_poly, poly_scale)
	
	# Transform terrain polygon to world space
	var destructible_poly_global: PackedVector2Array = chunk.get_destructible_global()
	
	# Do clipping operations in global space
	var clipping_results = Geometry2D.clip_polygons(destructible_poly_global, projectile_poly_global)
	
	# This means the chunk was destroyed so we need to queue_free
	if clipping_results.is_empty():
		print_debug("damage(%s) completely destroyed by poly=%s" % [name, projectile_poly.owner.name])
		delete_chunk(chunk)
		return
	
	var updated_destructible_poly = clipping_results[0]
	print_debug("damage(%s) Clip result with %s - Changing from size of %d to %d" 
		% [name, projectile_poly.owner.name, destructible_poly_global.size(), updated_destructible_poly.size()])
	
	# This could result in new chunks breaking off
	var destructible_chunk_results := chunk.replace_contents(updated_destructible_poly, projectile_poly_global, chunk_update_flags)
	if !destructible_chunk_results.is_empty():
		_add_new_chunks(chunk, destructible_chunk_results, 0)
		
	# We updated the current chunk and no more chunks to add 
	if clipping_results.size() == 1:
		return
		
	_add_new_chunks(chunk, clipping_results, 1)

func crumble(chunk: DestructibleObjectChunk, influence_poly_global: PackedVector2Array, in_smoothing: bool = true) -> void:
	print_debug("%s - chunk=%s crumbling with influence_poly=%s" % [name, chunk.name, influence_poly_global])
	
	var update_flags:int = DestructibleObjectChunk.UpdateFlags.Crumble
	if in_smoothing:
		update_flags |= DestructibleObjectChunk.UpdateFlags.Smooth

	# Kind of a hack but pass in the same contents to just invoke the crumbling
	var destructible_chunk_results := chunk.replace_contents(chunk.get_destructible_global(), influence_poly_global, update_flags)
	if !destructible_chunk_results.is_empty():
		_add_new_chunks(chunk, destructible_chunk_results, 0)

func delete_chunk(chunk: DestructibleObjectChunk) -> void:
	chunk_destroyed.emit(chunk)
	chunk.delete()
	await get_tree().process_frame
	
	if get_chunk_count() == 0:
		delete()

func _add_new_chunks(incident_chunk: DestructibleObjectChunk,
 geometry_results: Array[PackedVector2Array], start_index: int) -> void:
	# Create additional chunk pieces for the remaining geometry results
	if !create_new_chunks:
		print_debug("_add_new_chunks(%s) New chunks disabled - ignoring additional %d chunk pieces" % [name, geometry_results.size() - start_index])
		return

	for i in range(start_index, geometry_results.size()):
		var new_clip_poly = geometry_results[i]

		# Ignore clockwise results as these are "holes" and need to handle these differently later
		if TerrainUtils.is_invisible_polygon(new_clip_poly, false):
			print_debug("_add_new_chunks(%s) Ignoring 'hole' polygon for clipping result[%d] of size %d" 
				% [name, i, new_clip_poly.size()])
			continue
			
		var current_child_count: int = get_chunk_count()		
		var new_chunk_name = initial_chunk_name + str(i + current_child_count)
		
		print_debug("_add_new_chunks(%s) Creating new chunk(%s) for clipping result[%d] of size %d"
			% [name, new_chunk_name, i, new_clip_poly.size()])
		
		# Must be called deferred - see additional comment in _add_new_chunk as to why
		call_deferred("_add_new_chunk", incident_chunk, new_chunk_name, new_clip_poly)
	
func _add_new_chunk(incident_chunk: DestructibleObjectChunk = null, chunk_name: String = "", new_clip_poly: PackedVector2Array = []) -> DestructibleObjectChunk:
	if not chunk_scene:
		push_error("%s - No chunk_scene set" % [name])
		return null
	var new_chunk:Node = chunk_scene.instantiate() as DestructibleObjectChunk
	if not new_chunk:
		push_error("%s - chunk_scene %s is not a DestructibleObjectChunk" % [name, chunk_scene.resource_path])
		return null

	if chunk_name:
		new_chunk.name = chunk_name

	# Set the density of the new chunk to be same if we are splitting it from an existing chunk
	if incident_chunk: 
		new_chunk.density = incident_chunk.density
	
	add_child(new_chunk)
	# Must be done after adding as a child
	new_chunk.owner = self

	# Will be empty if creating the first chunk as using the default values from the chunk_scene
	if new_clip_poly:
		new_chunk.replace_contents(new_clip_poly)

	if incident_chunk:
		chunk_split.emit(incident_chunk, new_chunk)

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

func get_area() -> float:
	var area:float = 0.0
	for chunk in get_chunks():
		area += chunk.get_area()
	return area
	
func delete() -> void:
	print_debug("DestructibleObject(%s) - delete" % [name])
	destroyed.emit(self)

	queue_free.call_deferred()

func _to_string() -> String:
	return name
