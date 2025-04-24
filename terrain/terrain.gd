class_name Terrain extends Node2D

const TerrainChunkScene = preload("res://terrain/terrain_chunk.tscn")

@export_category("Smoothing")
@export var smooth_offset: float = 3

@export_category("Collapsing")
@export var falling_offset: float = 3

@export_category("Crushing")
@export var max_overlap_distance: float = 5

@export_category("Crushing")
@export var max_overlap_association_distance: float = 15

@export_category("Crushing")
@export var max_crush_triangle_delete_size: float = 150

## Customize the types of chunks that can break off when the terrain is being destroyed
@export_group("Chunks")

## DestructibleObject derived scenes
@export_category("Destructible")

## Optional chunk scene for rigid body chunks that can break off when the terrain breaks
@export var destructible_chunk_scene: PackedScene
@export var destructible_area_threshold_range:Vector2

## ShatterableObject derived scenes
@export_category("Shatterable")

@export var shatterable_chunk_scene: PackedScene
@export var shatterable_area_threshold_range:Vector2

@export_group("")

var initial_chunk_name: String
var first_child_chunk: TerrainChunk

@onready var _destructible_shape_calculator: DestructibleShapeCalculator = $DestructibleShapeCalculator

## Fires when a piece of the terrain is destroyed
## This could be a TerrainChunk static body, some kind of destructible object chunk that is in the TerrainChunk group
## or a shatterable object chunk that is in the TerrainChunk group and has broken into pieces
@warning_ignore("unused_signal")
signal chunk_split(chunk: Node2D,  new_chunk: Node2D)

# TODO: Currently we are not destroying the whole terrain when all chunks destroyed
# and this could have other impacts to other systems that rely on the object existing
## Fires when there are no more chunks left on the terrain
@warning_ignore("unused_signal")
signal destroyed(terrain: Terrain)

## Fires when a piece of the terrain is destroyed
## This could be a TerrainChunk static body, some kind of destructible object chunk that is in the TerrainChunk group
## or a shatterable object chunk that is in the TerrainChunk group and has broken into pieces
@warning_ignore("unused_signal")
signal chunk_destroyed(terrain_chunk: PhysicsBody2D)

func _ready():

	first_child_chunk = get_first_chunk()
	initial_chunk_name = first_child_chunk.name
	
	for chunk in get_children():
		if chunk.is_in_group(Groups.TerrainChunk):
			chunk.owner = self

#TODO: We should never delete the first chunk but sometimes this is happening
func get_first_chunk() -> TerrainChunk:
	if is_instance_valid(first_child_chunk):
		return first_child_chunk
	for chunk in get_children():
		if chunk is TerrainChunk:
			first_child_chunk = chunk
			return chunk
	return null

# Based on https://www.youtube.com/watch?v=FiKsyOLacwA
# poly_scale will determine the size of the explosion that destroys the terrain

# TODO: Think projectile_poly should be a property of the WeaponProjectile and then can call .get_projectile_poly_global to
# get the randomized damage polygon
# Only static TerrainChunk objects are damaged this way - other destructible or shatterable chunks are handled in their respective classes
func damage(terrainChunk: TerrainChunk, projectile: WeaponProjectile, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	print_debug("%s - chunk=%s damaged by %s with poly_scale=%s" % [name, terrainChunk.name, projectile.name, poly_scale])

	#print("Clipping terrain with polygon:", projectile_poly.polygon)
	var projectile_poly: CollisionPolygon2D = projectile.get_destructible_component()
	var projectile_poly_global: PackedVector2Array = _destructible_shape_calculator.get_projectile_poly_global(projectile_poly, poly_scale)
	
	# Transform terrain polygon to world space
	var terrain_poly_global: PackedVector2Array = terrainChunk.get_terrain_global()

	#print("clip - terrain poly in world space")
	#print_poly(terrain_poly_global)
	
	# Do clipping operations in global space
	var clipping_results = Geometry2D.clip_polygons(terrain_poly_global, projectile_poly_global)
	
	# This means the chunk was destroyed so we need to queue_free
	if clipping_results.is_empty():
		print("damage(" + name + ") completely destroyed by poly=" + projectile_poly.owner.name)
		_delete_chunk(terrainChunk)
		return
	
	var updated_terrain_poly = clipping_results[0]
	print("damage(" + name + ") Clip result with " + projectile_poly.owner.name +
	 " - Changing from size of " + str(terrain_poly_global.size()) + " to " + str(updated_terrain_poly.size()))

	#print("old poly (WORLD):")
	#print_poly(terrain_poly_global)
	#print("new poly (WORLD):")
	#print_poly(updated_terrain_poly)
	
	# This could result in new chunks breaking off
	var terrain_chunk_results := terrainChunk.replace_contents(updated_terrain_poly, projectile_poly_global)
	if !terrain_chunk_results.is_empty():
		_add_new_chunks(get_first_chunk(), terrain_chunk_results, 0)
		
	# We updated the current chunk and no more chunks to add 
	if clipping_results.size() == 1:
		return
		
	_add_new_chunks(get_first_chunk(), clipping_results, 1)
			
func _add_new_chunks(first_chunk: TerrainChunk,
 geometry_results: Array[PackedVector2Array], start_index: int) -> void:
	# Create additional terrain pieces for the remaining geometry results
	
	for i in range(start_index, geometry_results.size()):
		var new_clip_poly = geometry_results[i]

		# Ignore clockwise results as these are "holes" and need to handle these differently later
		if TerrainUtils.is_invisible_polygon(new_clip_poly, false):
			print("_add_new_chunks(" + name + ") Ignoring 'hole' polygon for clipping result[" + str(i) + "] of size " + str(new_clip_poly.size()))
			continue
			
		var current_child_count: int = get_chunk_count()		
		var new_chunk_name = initial_chunk_name + str(i + current_child_count)
		
		print("_add_new_chunks(" + name + ") Creating new terrain chunk(" + new_chunk_name + ") for clipping result[" + str(i) + "] of size " + str(new_clip_poly.size()))
		
		# Must be called deferred - see additional comment in _add_new_chunk as to why
		call_deferred("_add_new_chunk", first_chunk, new_chunk_name, new_clip_poly)

func get_chunk_count() -> int:
	var count:int = 0
	for chunk in get_children():
		if chunk.is_in_group(Groups.TerrainChunk):
			count += 1
	return count
	
#region New Terrain Chunk

func _add_new_chunk(prototype_chunk: TerrainChunk, chunk_name: String, new_clip_poly: PackedVector2Array) -> void:
	# TODO: Have some criteria on whether this will be a static chunk, or a destructible chunk or shatterable chunk
	# to be specified as separate prototype scenes
	# Will need to pass in some of the projectile characteristics like impact velocity and direction
	# so that the right impulse is applied when it is created for rigid body chunks
	# Can't just pass in the WeaponProjectile as it will be destroyed by the time this is called since it is called deferred
	# Store these in a struct-like class
	# Will also need a way to copy over the terrain texture so it is seamlessly applied to the new chunk

	# TODO: Right now the texture resource application is broken for new chunks - this happens on the whitecaps
	# So need to solve for that as well
	var new_chunk:Node2D = null
	
	if not destructible_chunk_scene or not shatterable_chunk_scene:
		var poly_area:float = TerrainUtils.calculate_polygon_area(new_clip_poly)

		if shatterable_chunk_scene and poly_area >= shatterable_area_threshold_range.x and poly_area <= shatterable_area_threshold_range.y:
			# TODO: Create shatterable object scene
			pass
		elif destructible_chunk_scene and poly_area >= destructible_area_threshold_range.x and poly_area <= destructible_area_threshold_range.y:
			# TODO: Create destructible object scene
			pass

	# Fallback to default chunk strategy
	if not new_chunk:
		new_chunk = _create_default_chunk(prototype_chunk, chunk_name, new_clip_poly)

	# TODO: For destructible_object always pass in incident chunk and this is usually main one
	# but chunks could subdivide after initial splitting so should account for that in the parameter
	chunk_split.emit(prototype_chunk, new_chunk)

	print_debug("added new chunk=%s - chunk count=%d" % [new_chunk.name, get_chunk_count()])


func _create_default_chunk(prototype_chunk: TerrainChunk, chunk_name: String, new_clip_poly: PackedVector2Array) -> Node2D:
	var new_chunk = TerrainChunkScene.instantiate()
	_configure_new_chunk(new_chunk, chunk_name)
	
	_update_chunk_from_prototype(prototype_chunk, new_chunk)

	new_chunk.replace_contents(new_clip_poly)

	return new_chunk

func _configure_new_chunk(new_chunk: Node2D, chunk_name: String) -> void:
	new_chunk.name = chunk_name
	# By definition a disconnected chunk could be falling so we will let it test for that
	new_chunk.falling = true
	
	# Get an error when this is called upstream from weapon_projectile.on_body_entered() -
	# E 0:00:34:0608   terrain.gd:137 @ _add_new_chunk(): Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.
	add_child(new_chunk)
	# Must be done after adding as a child
	new_chunk.owner = self

func _update_chunk_from_prototype(prototype_chunk: Node2D, new_chunk: Node2D) -> void:
	# Put the new chunk with same positioning was existing
	new_chunk.global_transform = prototype_chunk.global_transform
	new_chunk.z_index = prototype_chunk.z_index

#endregion

func _morph_falling_chunk(chunk: TerrainChunk) -> PackedVector2Array:
	var falling_transform: Transform2D = Transform2D(0, Vector2(0, falling_offset))
	var chunk_poly = falling_transform * chunk.get_terrain_global()

	# now apply the smoothing offset
	# TODO: This causes way too many polygons to be generated and the frame rate craters
	# var results := Geometry2D.offset_polygon(chunk_poly, smooth_offset, Geometry2D.JOIN_ROUND)
	# return results[0] if results.size() >= 1 else []
	return chunk_poly

func merge_chunks(in_first_chunk: TerrainChunk, in_second_chunk: TerrainChunk) -> bool:
	var largest_is_first := in_first_chunk.compare(in_second_chunk)
	var first_chunk := in_first_chunk if largest_is_first else in_second_chunk
	var second_chunk := in_second_chunk if largest_is_first else in_first_chunk
		
	var first_poly: PackedVector2Array
	var second_poly: PackedVector2Array 
	
	var falling:bool = false
	# If the chunk is falling then need to offset it
	if first_chunk.falling:
		first_poly = _morph_falling_chunk(first_chunk)
		falling = true
	else:
		first_poly = first_chunk.get_terrain_global()
	
	if second_chunk.falling:
		second_poly = _morph_falling_chunk(second_chunk)
		falling = true
	else:
		second_poly = second_chunk.get_terrain_global()
	
	#  Want to crush small pieces that get merged
	var results: Array[PackedVector2Array]
	
	var influence_vertices: PackedVector2Array = []

	var stop_falling:bool = true
	
	if falling:
		var crush_results := _crush(first_chunk, first_poly, second_chunk, second_poly, influence_vertices)
		results = crush_results["results"]
		stop_falling = crush_results["pruned"] == 0
	else:
		results = [first_poly, second_poly]
	
	if results.size() >= 2:	
		results = Geometry2D.merge_polygons(results[0], results[1])
		print_debug("merge_chunks(merge_polygons): first=%s(%d) + second=%s(%d) -> %d: [%s]"
		 % [first_chunk.name, first_poly.size(), second_chunk.name, second_poly.size(), results.size(),
		 ",".join(results.map(func(x : PackedVector2Array): return x.size()))])
		# Sort by size so we can keep the largest
		results = results.filter(func(r : PackedVector2Array): return TerrainUtils.is_visible_polygon(r, false))
		results.sort_custom(TerrainUtils.largest_poly_first)
	
	# Don't do crumbling when merging - pass 0 for flags
	if results.size() >= 1:
		first_chunk.replace_contents(results[0], influence_vertices, 0)
	else:
		_delete_chunk(first_chunk)
	
	if results.size() >= 2:
		second_chunk.replace_contents(results[1], influence_vertices, 0)
	else:
		_delete_chunk(second_chunk)
		
	if results.size() >= 3:
		# Children added deferred so printing will happen on the add
		_add_new_chunks(get_first_chunk(), results, 2)
	else:
		print("merge_chunks: size=%d -> [%s]" % [results.size(),
		 ",".join([first_chunk.name, second_chunk.name]) if results.size() == 2 else str(first_chunk.name) if results.size() == 1 else ""])
	
	return stop_falling
	
func _delete_chunk(chunk: TerrainChunk) -> void:
	# TODO: Need to listen for child DestructibleObject or ShatterableObject deletion signals and then re-propagate them here
	# There is some inconsistency here as the "chunk_count" will apply to the full destructible or shatterable object
	# For shatterable for sure want to only emit when the full object is shattered into pieces
	# For destructibleObject if we end up supporting multiple chunks each chunk being destroyed should emit a separate event
	# as these events are more discrete
	# The destroyed chunks will always be the chunk classes of either TerrainChunk or a derived class of DestructibleObjectChunk or ShatterableObjectChunk
	# These all have the common base class PhysicsBody2D
	chunk_destroyed.emit(chunk)
	chunk.delete()
	await get_tree().process_frame
	
	if get_chunk_count() == 0:
		destroyed.emit(self)
		
# Need to specify which poly is falling and if so check delta y down and up to see which vertices will get merged and then
# any other vertex within a sq dist influence of that will be also considered for "crushing" by testing the area of those polygons
# if for some reason no vertices match then just return the original poly arrays without triangulation
func _crush(first_chunk: TerrainChunk, first_poly: PackedVector2Array,
	 second_chunk: TerrainChunk, second_poly: PackedVector2Array, out_influence_vertices: PackedVector2Array) -> Dictionary:
	
	var results: Array[PackedVector2Array] = [first_poly, second_poly]

	if !first_chunk.falling and !second_chunk.falling:
		return { "results" : results, "pruned" : 0 }
		
	# Determine the candidate vertices
	var overlap_index_arrays : Array[PackedInt32Array] = TerrainUtils.determine_overlap_vertices(first_poly, second_poly, max_overlap_association_distance, max_overlap_distance)
	
	# influence vertices doesn't have to be a true polygon - we create a bounding circle around the vertices
	# Calculate the influence area before pruning
	for index in overlap_index_arrays[0]:
		out_influence_vertices.push_back(first_poly[index])
	for index in overlap_index_arrays[1]:
		out_influence_vertices.push_back(second_poly[index])

	# Modifying the main terrain chunk by pruning vertices ends up causing unintended side effects like having unrelated terrain become angular and
	# cause artillery and houses to "pop up" on top as they end up inside so disabling modifying that
	var pruned: int = 0
	
	# Not modifying the initial terrain chunk causes weird stems still - compensate with smaller overlap association distance
	#if first_chunk != first_child_chunk:
	if true:
		print_debug("pruning terrainChunk(%s): vertexCount=%d" % [first_chunk.name, first_poly.size()])
		pruned += TerrainUtils.prune_small_area_poly(first_poly, overlap_index_arrays[0], max_crush_triangle_delete_size)
	else:
		print_debug("pruning terrainChunk(%s) - SKIP as this is main terrain" % [first_chunk.name])

	print_debug("pruning terrainChunk(%s): vertexCount=%d" % [second_chunk.name, second_poly.size()])
	pruned += TerrainUtils.prune_small_area_poly(second_poly, overlap_index_arrays[1], max_crush_triangle_delete_size)

	# Filter results to visible
	results = results.filter(func(r : PackedVector2Array): return TerrainUtils.is_visible_polygon(r, false))
	results.sort_custom(TerrainUtils.largest_poly_first)

	print_debug("pruning: final_results=%d; pruned=%d" % [results.size(), pruned])

	if results.size() <= 2:
		return { "results" : results, "pruned" : pruned }
		
	# Take largest two - though right now we will always have two at this point
	return {
		"results" : results.slice(0, 2),
		"pruned" : pruned
	}
	
func contains_point(point: Vector2) -> bool:
	for chunk in get_children():
		if chunk is TerrainChunk:
			if chunk.contains_point(point):
				return true
	return false

func get_chunks() -> Array[Node]:
	var chunks : Array[Node] = []
	for child in get_children():
		if child.is_in_group(Groups.TerrainChunk):
			chunks.push_back(child)
	return chunks
	
func get_bounds_global() -> Rect2:
	var bounds:Rect2 = Rect2()
	
	for chunk in get_chunks():
		bounds = bounds.merge(chunk.get_bounds_global())
	return bounds

func _to_string() -> String:
	return name
