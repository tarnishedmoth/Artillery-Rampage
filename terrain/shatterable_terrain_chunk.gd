class_name ShatterableTerrainChunk extends ShatterableObject

## Scene of type ShatterableObjectBody
@export_category("Chunk")
@export var chunk_scene: PackedScene

var initial_poly: PackedVector2Array
var texture_resources: Array[TerrainChunkTextureResource]

var initial_velocity: Vector2
var impact_point_global: Vector2

func _ready() -> void:
	var chunk: ShatterableObjectBody = _create_chunk_scene()
	if chunk:
		# F*dt = m*dv -> Impulse is change in momentum
		chunk.apply_impulse(initial_velocity * chunk.mass, impact_point_global - chunk.global_position)
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
	
