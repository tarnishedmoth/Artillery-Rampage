class_name DestructibleTerrainChunkBody extends DestructibleObjectChunk

@export_group("Textures")
@export var texture_resources: Array[TerrainChunkTextureResource]

@export_group("Physics")
## Crumble on impact with other objects if > 0
@export var crumble_impulse_threshold: float = 1.0
@export var impulse_crumbling_enabled: bool = false

@export var influence_poly_size_v_impulse: Curve
@export var enable_impulse_crumble_smoothing: bool = true

func _ready() -> void:
	if impulse_crumbling_enabled and crumble_impulse_threshold > 0 and influence_poly_size_v_impulse:
		contact_monitor = true
	else:
		impulse_crumbling_enabled = false
		
	super._ready()
	apply_textures()
	
func apply_textures() -> void:
	for resource in texture_resources:
		if resource.matches(self):
			resource.apply_to_mesh(_mesh)
			break

# func _update_poly_local(new_poly: PackedVector2Array) -> void:
# 	super._update_poly_local(new_poly)
# 	_recenter_polygon()

# func _recenter_polygon() -> void:
# 	# Should recenter the polygon about its new center of mass (centroid)
# 	var centroid: Vector2 = TerrainUtils.polygon_centroid(_mesh.polygon)
# 	# We want the centroid to be the rigid body center
# 	#position = Vector2.ZERO
# 	#_mesh.position = -centroid
# 	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
# 	#center_of_mass = Vector2.ZERO
# 	center_of_mass = centroid

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	super._integrate_forces(state)
	
	if not impulse_crumbling_enabled or state.get_contact_count() == 0:
		return
	
	var impulse: Vector2 = state.get_contact_impulse(0)
	if impulse.length_squared() < crumble_impulse_threshold * crumble_impulse_threshold:
		return
	
	var impulse_length: float = impulse.length()
	var impulse_ratio = impulse_length / crumble_impulse_threshold
	var influence_poly_size: float = influence_poly_size_v_impulse.sample_baked(impulse_ratio)
	
	print_debug("%s - crumble impulse exceeded: threshold=%f impulse=%f -> influence_poly_size=%f" % [name, crumble_impulse_threshold, impulse_length, influence_poly_size])

	var contact_pos: Vector2 = state.get_contact_local_position(0)
	
	# Create a rectangle PackedVector2Array with the contact_pos at center and the given size as the width and height
	var influence_poly: PackedVector2Array = []
	influence_poly.resize(4)

	var poly_half_size: float = influence_poly_size * 0.5

	influence_poly[0] = contact_pos + Vector2(-poly_half_size, -poly_half_size)
	influence_poly[1] = contact_pos + Vector2(poly_half_size, -poly_half_size)
	influence_poly[2] = contact_pos + Vector2(poly_half_size, poly_half_size)
	influence_poly[3] = contact_pos + Vector2(-poly_half_size, poly_half_size)

	owner.crumble(self, influence_poly, enable_impulse_crumble_smoothing)
