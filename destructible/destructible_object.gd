class_name DestructibleObject extends Node2D

@export_category("Chunk")
@export
var chunk_scene: PackedScene

var initial_chunk_name: String
var first_child_chunk: DestructibleObjectChunk

func _ready() -> void:
	first_child_chunk = get_first_chunk()
	if !first_child_chunk:
		# Create the first chunk from scene
		first_child_chunk = _add_new_chunk()
	initial_chunk_name = first_child_chunk.name
	
	for chunk in get_children():
		if chunk is DestructibleObjectChunk:
			chunk.owner = self

func get_first_chunk() -> DestructibleObjectChunk:
	if is_instance_valid(first_child_chunk):
		return first_child_chunk
	for chunk in get_children():
		if chunk is DestructibleObjectChunk:
			first_child_chunk = chunk
			return chunk
	return null
	
func damage(chunk: DestructibleObjectChunk, projectile_poly: CollisionPolygon2D, poly_scale: Vector2 = Vector2(1,1)):
	print_debug("%s - chunk=%s damaged by %s with poly_scale=%s" % [name, chunk.name, projectile_poly.name, poly_scale])
	
	# TODO: Implement damage logic similar to Terrain

	
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

	print_debug("added new chunk=%s - chunk count=%d" % [new_chunk.name, get_child_count()])

	return new_chunk
