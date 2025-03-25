class_name TerrainChunkTextureResource extends Resource

@export var texture: Texture2D
@export var repeat: CanvasItem.TextureRepeat
@export var offset: Vector2

# Make sure that every parameter has a default value.
# Otherwise, there will be problems with creating and editing
# your resource via the inspector.
func _init(p_texture:Texture2D = null, p_repeat: CanvasItem.TextureRepeat = CanvasItem.TextureRepeat.TEXTURE_REPEAT_DISABLED, p_offset: Vector2 = Vector2.ZERO):
	texture = p_texture
	repeat = p_repeat
	offset = p_offset
	 
# TODO: We can add more complex logic to see if this resource meets the criteria of the chunk
func matches(_chunk: TerrainChunk) -> bool:
	return true
	
func apply_to(chunk: TerrainChunk) -> void:
	var mesh: Polygon2D = chunk.terrainMesh
	
	mesh.set_texture(texture)
	mesh.texture_repeat = repeat
	mesh.texture_offset = offset
