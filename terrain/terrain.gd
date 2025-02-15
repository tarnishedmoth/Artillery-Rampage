class_name Terrain extends Node2D

const TerrainChunkScene = preload("res://terrain/terrain_chunk.tscn")

var initial_chunk_name: String
# Based on https://www.youtube.com/watch?v=FiKsyOLacwA
# poly_scale will determine the size of the explosion that destroys the terrain

func _ready():
	initial_chunk_name = get_child(0).name
	
func damage(terrainChunk: TerrainChunk, projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	
	#print("Clipping terrain with polygon:", projectile_poly.polygon)
	var scale_transform: Transform2D = Transform2D(0, poly_scale, 0, Vector2())
	# Combine the scale transform with the world (global) transform
	var combined_transform: Transform2D = projectile_poly.global_transform * scale_transform
	
	var projectile_poly_global: PackedVector2Array = combined_transform * projectile_poly.polygon
	
	# Transform terrain polygon to world space
	var terrain_poly_global: PackedVector2Array = terrainChunk.get_terrain_global()

	#print("clip - terrain poly in world space")
	#print_poly(terrain_poly_global)
	
	# Do clipping operations in global space
	var clipping_result = Geometry2D.clip_polygons(terrain_poly_global, projectile_poly_global)
	
	# This means the chunk was destroyed so we need to queue_free
	if clipping_result.is_empty():
		print("damage(" + name + ") completely destroyed by poly=" + projectile_poly.owner.name)
		terrainChunk.queue_free()
		return
	
	var updated_terrain_poly = clipping_result[0]
	print("damage(" + name + ") Clip result with " + projectile_poly.owner.name +
	 " - Changing from size of " + str(terrain_poly_global.size()) + " to " + str(updated_terrain_poly.size()))

	#print("old poly (WORLD):")
	#print_poly(terrain_poly_global)
	#print("new poly (WORLD):")
	#print_poly(updated_terrain_poly)
	
	terrainChunk.replace_contents(updated_terrain_poly)
	
	# We updated the current chunk and no more chunks to add 
	if clipping_result.size() == 1:
		return
		
	# Create additional terrain pieces for the remaining clipping results
	# iterate through the remaining clipping results
	
	var current_child_count: int = get_child_count()
	
	for i in range(1, clipping_result.size()):
		var new_clip_poly = clipping_result[i]
		
		var new_chunk_name = initial_chunk_name + str(i + current_child_count)
		
		print("damage(" + name + ") Creating new terrain chunk(" + new_chunk_name + ") for clipping result[" + str(i) + "] of size " + str(new_clip_poly.size()))
		_add_new_chunk(terrainChunk, new_chunk_name, new_clip_poly)
	

func _add_new_chunk(prototype_chunk: TerrainChunk, name: String, new_clip_poly: PackedVector2Array):
	var new_chunk = TerrainChunkScene.instantiate()
	new_chunk.name = name
	
	add_child(new_chunk)
	# Must be done after adding as a child
	new_chunk.owner = self
	
	# Put the new chunk with same positioning was existing
	new_chunk.global_transform = prototype_chunk.global_transform
	new_chunk.z_index = prototype_chunk.z_index

	new_chunk.replace_contents(new_clip_poly)
