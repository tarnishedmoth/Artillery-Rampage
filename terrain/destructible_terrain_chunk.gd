class_name DestructibleTerrainChunk extends DestructibleObject

var initial_velocity: Vector2
var impact_point_global: Vector2

func _ready() -> void:
	super._ready()

	if get_chunk_count() > 0:
		var chunk: DestructibleObjectChunk = get_chunks()[0]
		# F*dt = m*dv -> Impulse is change in momentum
		chunk.apply_impulse(initial_velocity * chunk.mass, impact_point_global - chunk.global_position)
