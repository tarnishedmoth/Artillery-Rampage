class_name TerrainChunkTextureOutlineResource extends TerrainChunkTextureResource

# TODO: Could add an alternative outline for damaged section and use the inverse of the mask to mix that texture in the shader
## Minimum distance from damaged section to not apply the primary outline. Set to < 0 to disable the behavior
@export var outline_distance_threshold: float = 5.0

func _init(
	p_texture:Texture2D = null,
	p_material:Material = null,
	p_repeat: CanvasItem.TextureRepeat = CanvasItem.TextureRepeat.TEXTURE_REPEAT_DISABLED,
	p_offset: Vector2 = Vector2.ZERO
	):
		super(p_texture, p_material, p_repeat, p_offset)
		
func apply_to(object: Node2D, args: Array = []) -> bool:
	var outline_mesh:Line2D = object as Line2D
	if not outline_mesh:
		return super.apply_to(object, args)
	var impact_vertices:PackedVector2Array = args[0] as PackedVector2Array if not args.is_empty() else PackedVector2Array()
	apply_to_outline(outline_mesh, impact_vertices)
	return true
		
func apply_to_outline(line: Line2D, impact_vertices: PackedVector2Array) -> void:
	var shader_material = material as ShaderMaterial
	if shader_material:
		var discarded_outline_indices:PackedByteArray = _compute_discarded_indices(line, impact_vertices)
		var packed_discard_flags:PackedInt32Array = _pack_discard_flags(discarded_outline_indices)
		shader_material.set_shader_parameter("discarded_vertex_flags", packed_discard_flags)
	line.material = material
	line.set_texture(texture)
	line.texture_repeat = repeat
	# Line2D doesn't support texture_offset


func _compute_discarded_indices(line: Line2D, impact_vertices: PackedVector2Array)  -> PackedByteArray:
	# TODO: Need to match the line points against the input ranges
	# TODO: The ranges also need to be compute in replace_contents and utilize the new get_destroyed_range function
	var index_flags:PackedByteArray = []
	var line_points:PackedVector2Array = line.points

	# Need to multiply by 2 because it turns the line into a polygon and half the vertices will be the top and half the bottom so everything has to be roughly doubled
	# Will zero init which discards nothing by default, which is what we want since "1" discards and "0" draws
	index_flags.resize(line_points.size() * 2)

	if impact_vertices.is_empty() or outline_distance_threshold < 0:
		return index_flags

	impact_vertices.sort()

	var line_start_index:int = 0
	var line_end_index:int = line_points.size()

	# Initial optimization to cull points outside of all range
	var min_x:float = impact_vertices[0].x
	var max_x:float = impact_vertices[-1].x

	for i in line_points.size():
		var point:Vector2 = line_points[i]
		if line_start_index == 0 and point.x >= min_x:
			line_start_index = i
		elif line_end_index == line_points.size() and point.x > max_x:
			line_end_index = i
		elif line_start_index > 0 and line_end_index != line_points.size():
			break

	var threshold_dist:float = outline_distance_threshold * outline_distance_threshold

	for i in range(line_start_index, line_end_index):
		var point:Vector2 = line_points[i]
		# Determine if point is in the damaged set
		var damaged_start_index:int = impact_vertices.bsearch(point, true)
		if damaged_start_index == impact_vertices.size():
			break
		var damaged_end_index:int = impact_vertices.bsearch(point + Vector2(outline_distance_threshold,0.0), false)
		if damaged_end_index == impact_vertices.size():
			damaged_end_index -= 1
		for j in range(damaged_start_index, damaged_end_index + 1):
			var damage_point:Vector2 = impact_vertices[j]
			if point.distance_squared_to(damage_point) <= threshold_dist:
				var index_start = 2 * i #Have to add the points twice and they are ordered in segment pairs
				index_flags[index_start] = 1
				index_flags[index_start + 1] = 1
				break
	
	return index_flags

## Packs the bool array of discard flags corresponding to vertex indices into an int32 flag array to compress it by a factor of 32 for the shader parameter
## Shader parameters don't support bool[] or byte[] and only int[]
static func _pack_discard_flags(flags: PackedByteArray) -> PackedInt32Array:
	var packed: PackedInt32Array = []
	# Preallocate the buffer
	packed.resize(ceili(flags.size() / 32.0))
	
	var current:int = 0
	var count:int = 0
	
	for i in flags.size():
		var bit:int = flags[i] & 1
		current |= bit << (i % 32)
		if i % 32 == 31:
			packed[count] = current
			current = 0
			count += 1
	# Set last bit information
	if current != 0:
		packed[count] = current
	return packed
