class_name PrecomputedShatterableObjectBody extends ShatterableObjectBody

@export_group("Fracture Sets")
@export
var fractured_mesh_sets: Array[PackedScene] = []

func _ready() -> void:
	if not fractured_mesh_sets:
		push_error("PrecomputedShatterableObjectBody(%s) - No fracture mesh scenes set" % [name])
	super._ready()

func _create_shatter_nodes(impact_velocity: Vector2) -> Array[Node2D]:
	# Choose a scene at random
	var mesh_set: PackedScene = fractured_mesh_sets.pick_random()
	if not mesh_set:
		return []

	var fracture_mesh_set:RigidBodyFracturedMesh = mesh_set.instantiate() as RigidBodyFracturedMesh
	if not fracture_mesh_set:
		push_error("PrecomputedShatterableObjectBody(%s) - unable to instantiate %s as RigidBodyFracturedMesh" % [name, mesh_set.resource_path])
		return []

	var impact_velocity_dir: Vector2 = _compute_impact_velocity_dir(impact_velocity)

	# Need to add scene in order for the child nodes to be accessible
	add_child(fracture_mesh_set)

	for node in fracture_mesh_set.pieces:
		# detach from current parent
		node.get_parent().remove_child(node)

		_init_node(node)
		_apply_impulse_to_new_body(node, node.mesh.polygon, impact_velocity_dir)
		_adjust_new_body_collision(node)
	
	remove_child(fracture_mesh_set)
	fracture_mesh_set.queue_free()

	var nodes:Array[Node2D]
	nodes.assign(fracture_mesh_set.pieces)
	
	return nodes

func _init_node(new_instance:RigidMeshBody) -> void:
	new_instance._init_owner = owner
		
	new_instance.density = density
	new_instance.position = position
	new_instance.rotation = rotation

	# Skipped ready first time since needed to add to the tree in order to access the rigid body mesh instances
	# Now need to opt-into it now that all init values are set and request ready to run again once node is added back in 
	# tree in parent ShatterableObject
	new_instance.invoke_ready = true
	new_instance.request_ready()
