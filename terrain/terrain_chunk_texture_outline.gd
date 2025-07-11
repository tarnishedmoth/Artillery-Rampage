class_name TerrainChunkTextureOutlineResource extends TerrainChunkTextureResource

# TODO: Could add an alternative outline for damaged section and use the inverse of the mask to mix that texture in the shader
## Minimum distance from damaged section to not apply the primary outline. Set to < 0 to disable the behavior
@export var outline_distance_threshold: float = 10.0
@export_range(0.1, 1.0, 0.01) var outline_mesh_outline_shader_fraction: float = 0.67

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
		var discarded_points:PackedVector2Array = _compute_discarded_vertices(line, impact_vertices)
				
		shader_material.set_shader_parameter("discarded_vertices", discarded_points)
		shader_material.set_shader_parameter("discarded_count", discarded_points.size())
		shader_material.set_shader_parameter("discard_match_distance", line.width * outline_mesh_outline_shader_fraction)
		shader_material.set_shader_parameter("modulate", ObjectUtils.get_effective_modulate(line))
		
	line.material = material
	line.set_texture(texture)
	line.texture_repeat = repeat
	# Line2D doesn't support texture_offset

func _compute_discarded_vertices(line: Line2D, impact_vertices: PackedVector2Array)  -> PackedVector2Array:
	var discarded_points:PackedVector2Array = []
	var line_points:PackedVector2Array = line.points

	if impact_vertices.is_empty() or outline_distance_threshold < 0:
		return discarded_points

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
		elif point.x > max_x:
			line_end_index = mini(line_end_index,i)
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
				discarded_points.push_back(point)
				break
	
	# Only needed if we do binary search in the shader
	#discarded_points.sort()
	return discarded_points
