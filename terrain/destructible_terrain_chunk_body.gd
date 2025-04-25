class_name DestructibleTerrainChunkBody extends DestructibleObjectChunk

@export_group("Textures")
@export var texture_resources: Array[TerrainChunkTextureResource]

func _ready() -> void:
	super._ready()
	apply_textures()
	
func apply_textures() -> void:
	for resource in texture_resources:
		if resource.matches(self):
			resource.apply_to_mesh(_mesh)
			break
