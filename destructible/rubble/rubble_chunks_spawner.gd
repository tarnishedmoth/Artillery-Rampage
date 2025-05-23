class_name RubbleChunksSpawner extends Node

@export var max_lifetime: float = 30.0

@export var min_body_impulse:float = 100
@export var max_body_impulse:float = 200

@export var max_rubble_count:int = 10

@export var min_velocity_angle_dev: float = 0
@export var max_velocity_angle_dev: float = 90

@export_range(0.1,1.0,0.01) var spawn_radius_fraction:float = 0.5

@onready var rubble_container:Node = $RubbleSpawnContainer
@onready var rubble_prototypes_container = $RubblePrototypes
@onready var destructible_poly_operations: DestructiblePolyOperations = $DestructiblePolyOperations

var rubble_prototypes:Array[RigidMeshBody] = []

func _ready() -> void:
	_extract_rubble_prototypes()
	
func _exit_tree():
	for prototype in rubble_prototypes:
		if is_instance_valid(prototype):
			prototype.queue_free()
	
func _extract_rubble_prototypes() -> void:
	for child in rubble_prototypes_container.get_children():
		if child is RigidMeshBody:
			rubble_prototypes.append(child)
			rubble_prototypes_container.remove_child(child)
		else:
			push_warning("%s - RubblePrototypes contains a non-RigidMeshBody node %s" % [name, child.name])
			child.queue_free()

	# Sort by increasing area as need this when spawning
	rubble_prototypes.sort_custom(func(a, b): return a.get_area() < b.get_area())

	print_debug("%s - Found %d rubble prototypes" % [name, rubble_prototypes.size()])

func spawn_rubble(destructible_poly_global:PackedVector2Array, orig_poly_global:PackedVector2Array) -> void:
	if max_rubble_count <= 0:
		return
	
	if not rubble_prototypes:
		print_debug("%s - spawn_rubble called with no rubble prototypes" % name)
		return

	var hole_poly_global:PackedVector2Array = destructible_poly_operations.get_destroyed_polys(destructible_poly_global, orig_poly_global)
	if not hole_poly_global:
		print_debug("%s - spawn_rubble resulted in empty destroyed poly" % name)
		return

	var hole_area:float = TerrainUtils.calculate_polygon_area(hole_poly_global)

	# Find all candidate prototypes that have area less than the hole area
	var rubble_candidates:Array[RigidMeshBody] = rubble_prototypes.filter(func(r): return r.get_area() < hole_area)

	if not rubble_candidates:
		print_debug("%s - spawn_rubble found no rubble candidates" % name)
		return

	var rubble_piece_indices: PackedInt32Array = []

	var bounding_circle:= Circle.create_from_points(hole_poly_global)

	var used_area:float = 0.0
	var last_index:int = mini(rubble_candidates.size(), max_rubble_count)

	# Keep trying to add successively until no piece can meet the total area restriction
	while last_index > 0:
		var largest_index_match:int = -1
		for i in last_index:
			var rubble:RigidMeshBody = rubble_candidates[i]
			var rubble_area:float = rubble.get_area()
			var new_used_area:float = used_area + rubble_area
			if new_used_area >= hole_area:
				break
			
			rubble_piece_indices.push_back(i)
			largest_index_match = i
			used_area = new_used_area
		last_index = mini(largest_index_match + 1, max_rubble_count - rubble_piece_indices.size())

	var angle_steps:int = 6
	var num_rings:int = ceili(rubble_piece_indices.size() / float(angle_steps))
	var radius_step:float = (bounding_circle.radius * spawn_radius_fraction) / (num_rings + 1)

	var spawn_radius: float = radius_step
	var angle_index:int = 0
	var circle_center:Vector2 = bounding_circle.center

	var impact_velocity_dir:Vector2 = Vector2.UP

	for index in rubble_piece_indices:
		var rubble_prototype:RigidMeshBody = rubble_prototypes[index]
		var new_instance: RigidMeshBody = rubble_prototype.duplicate()
		
		#Space out in concentric rings in the bounding circle to try and separate the pieces as much as possible
		# Physics engine will do the rest
		var angle:float = TAU / angle_steps * angle_index
		var pos:Vector2 = Vector2(
			spawn_radius * cos(angle) + circle_center.x,
			spawn_radius * sin(angle) + circle_center.y
		)

		_init_node(new_instance, pos)
		(func():
			rubble_container.add_child(new_instance)
			Collisions.add_exception_for_layer_and_group(new_instance, Collisions.Layers.tank, Groups.Unit)
			_apply_impulse_to_new_body(new_instance, new_instance.mesh.polygon, impact_velocity_dir)
		).call_deferred()
		
		if angle_index < angle_steps - 1:
			angle_index += 1
		else:
			angle_index = 0
			spawn_radius += radius_step

func _init_node(new_instance:RigidMeshBody, position:Vector2) -> void:
	new_instance._init_owner = owner
	new_instance.max_lifetime = max_lifetime
	new_instance.position = position
	new_instance.rotation = randf_range(-PI, PI)

#region impulse

# TODO: Copied and pasted from shatterable_object_body

func _apply_impulse_to_new_body(new_instance:RigidBody2D, poly: PackedVector2Array, impact_velocity_dir: Vector2) -> void:
	var impulse:Vector2 = _randomize_impact_velocity_dir(impact_velocity_dir) * randf_range(min_body_impulse, max_body_impulse)
	var location: Vector2 = _get_random_point_in_or_near_poly(poly)
	new_instance.apply_impulse(impulse, location)
	
func _randomize_impact_velocity_dir(impact_velocity_dir: Vector2) -> Vector2:
	var angle_dev: float = deg_to_rad(randf_range(min_velocity_angle_dev, max_velocity_angle_dev))
	var random_angle: float = angle_dev * MathUtils.randf_sgn()
	return impact_velocity_dir.rotated(random_angle)

func _get_random_point_in_or_near_poly(poly: PackedVector2Array) -> Vector2:
	var bounds:Rect2 = TerrainUtils.get_polygon_bounds(poly)

	var quarter_size: Vector2 = bounds.size * 0.25
	var x: float = randf_range(bounds.position.x + quarter_size.x, bounds.position.x + 3 * quarter_size.x)
	var y: float = randf_range(bounds.position.y + quarter_size.y, bounds.position.y + 3 * quarter_size.y)

	return Vector2(x, y)

#endregion
