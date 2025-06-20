class_name TerrainChunkTextureResource extends Resource

@export var texture: Texture2D
@export var material: Material
@export var repeat: CanvasItem.TextureRepeat
@export var offset: Vector2

# Make sure that every parameter has a default value.
# Otherwise, there will be problems with creating and editing
# your resource via the inspector.
func _init(
	p_texture:Texture2D = null,
	p_material:Material = null,
	p_repeat: CanvasItem.TextureRepeat = CanvasItem.TextureRepeat.TEXTURE_REPEAT_DISABLED,
	p_offset: Vector2 = Vector2.ZERO
	):
		
	texture = p_texture
	material = p_material
	repeat = p_repeat
	offset = p_offset
	 
# TODO: We can add more complex logic to see if this resource meets the criteria of the chunk
func matches(_obj: Node2D) -> bool:
	return true
	
func apply_to(object: Node2D, _args: Array = []) -> bool:
	if object is TerrainChunk:
		apply_to_mesh(object.terrainMesh)
		return true
	return _apply_to(object)

func apply_to_mesh(mesh: Polygon2D) -> void:
	mesh.material = material
	mesh.set_texture(texture)
	mesh.texture_repeat = repeat
	mesh.texture_offset = offset
	
## generic fallback version that sets the main properties on the node if it has the corresponding properties or methods
## If one or more of the key properties - material or set_texture don't exist then false is returned; otherwise, returns true
func _apply_to(node: Node2D) -> bool:
	var result:bool = true
	
	if "material" in node:
		node.material = material
	else:
		result = false
		
	if node.has_method("set_texture"):
		node.set_texture(texture)
	else:
		result = false
		
	if "texture_repeat" in node:
		node.texture_repeat = repeat
	if "texture_offset" in node:
		node.texture_offset = offset
		
	return result
