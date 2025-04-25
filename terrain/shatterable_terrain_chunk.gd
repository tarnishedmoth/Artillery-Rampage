class_name ShatterableTerrainChunk extends ShatterableObject

## Scene of type ShatterableObjectBody
@export_category("Chunk")
@export var chunk_scene: PackedScene

var initial_poly: PackedVector2Array
var texture_resources: Array[TerrainChunkTextureResource]

func _ready() -> void:
	_create_chunk_scene()

	super._ready()
	
func _create_chunk_scene() -> ShatterableTerrainBody:
	if not chunk_scene:
		push_error("%s - No chunk_scene set" % [name])
		return null

	var new_chunk:Node = chunk_scene.instantiate() as ShatterableTerrainBody
	if not new_chunk:
		push_error("%s - chunk_scene is not a ShatterableTerrainBody" % [name])
		return null

	# Must initialize the shatterable object poly before ready is run on it
	new_chunk._init_poly = initial_poly
	new_chunk._init_owner = self
	
	if texture_resources:
		new_chunk.texture_resources = texture_resources

	_body_container.add_child(new_chunk)

	return new_chunk
	
