class_name ShatterableTerrainBody extends ShatterableObjectBody

@export_group("Textures")
@export var texture_resources: Array[TerrainChunkTextureResource]

@export_group("Physics")
## Shatter on impact with other objects if > 0
@export var shatter_impulse_threshold: float = 1.0
@export var impulse_shatter_enabled: bool = false

func _ready() -> void:
	if impulse_shatter_enabled and shatter_impulse_threshold > 0:
		contact_monitor = true
	else:
		impulse_shatter_enabled = false
		
	super._ready()
	apply_textures()
	
func apply_textures() -> void:
	for resource in texture_resources:
		if resource.matches(self):
			resource.apply_to_mesh(_mesh)
			break

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not impulse_shatter_enabled or state.get_contact_count() == 0:
		return
	
	var impulse: Vector2 = state.get_contact_impulse(0)
	if impulse.length_squared() < shatter_impulse_threshold * shatter_impulse_threshold:
		return

	print_debug("%s - shatter impulse exceeded: threshold=%f impulse=%s" % [name, shatter_impulse_threshold, impulse])
	
	owner.shatter(self, -state.get_contact_local_velocity_at_position(0), state.get_contact_local_position(0))

# Override as poly is in global coordinates
func _recenter_polygon() -> void:
	# Should recenter the polygon about its new center of mass (centroid)
	var centroid: Vector2 = TerrainUtils.polygon_centroid(_mesh.polygon)
	# We want the centroid to be the rigid body center
	position = Vector2.ZERO
	#_mesh.position = -centroid
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	#center_of_mass = Vector2.ZERO
	center_of_mass = centroid
