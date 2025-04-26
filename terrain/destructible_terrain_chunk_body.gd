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

func _update_poly_local(new_poly: PackedVector2Array) -> void:
	super._update_poly_local(new_poly)
	_recenter_polygon()

func _recenter_polygon() -> void:
	# Should recenter the polygon about its new center of mass (centroid)
	var centroid: Vector2 = TerrainUtils.polygon_centroid(_mesh.polygon)
	# We want the centroid to be the rigid body center
	#position = Vector2.ZERO
	#_mesh.position = -centroid
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	#center_of_mass = Vector2.ZERO
	center_of_mass = centroid
