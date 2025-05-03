class_name ProceduralObjectSpawner extends Node2D

@export var objects:Array[ProceduralObjectContraints] = []
@export var randomize_object_priorities:bool = false

@onready var container:Node = $Container

@export var spawn_screen_deadzone: float = 20.0

var _sorted_insert_positions: Array[Rect2] = []

func _ready() -> void:
	await GameEvents.all_players_added

	_find_and_insert_tank_bounds()
	
	if randomize_object_priorities:
		objects.shuffle()
		
	for object_type in objects:
		_place_objects(object_type)

func _place_objects(object_type : ProceduralObjectContraints) -> void:
	var max_spawn_count:int = randi_range(object_type.count.x, object_type.count.y)
	if max_spawn_count <= 0:
		return
		
	var object_scene:PackedScene = object_type.scene
	if object_scene == null or not object_scene.can_instantiate():
		push_error("ProceduralObjectSpawner(%s): _place_objects() - object_scene is null" % [name])
		return

	var prototype_object:Node2D = object_scene.instantiate() as Node2D
	if prototype_object == null:
		push_error("ProceduralObjectSpawner(%s): _place_objects() - prototype_object is null" % [name])
		return
	
	# Needed to do calculations on the prototype
	container.add_child(prototype_object);
	# Get the bounding box of the prototype object
	var bounding_box:Rect2 = _get_bounding_box(prototype_object)
	container.remove_child(prototype_object)
	prototype_object.queue_free()

	var bounds:Rect2 = get_viewport().get_visible_rect()
	var half_width:float = bounding_box.size.x / 2

	var start_x:float = bounds.position.x + spawn_screen_deadzone + half_width
	var end_x:float = bounds.position.x + bounds.size.x - spawn_screen_deadzone - half_width
	var step:float = bounding_box.size.x + object_type.min_spacing

	var points: Array[float] = []
	var num_points:int = floori((end_x - start_x) / step)
	points.resize(num_points)
	
	var next_point_pos:float = start_x
	for i in num_points:
		next_point_pos += i * step + randf() * half_width
		points[i] = next_point_pos
				
	# Randomize the order of the points
	points.shuffle()
	var spawn_count:int = 0

	for point in points:
		# Check if we can place the object at this position
		var y:float = _get_placement_y_at(bounding_box, object_type, point)
		if y >= 0:
			# Spawn the object
			var new_object:Node2D = object_scene.instantiate() as Node2D
			assert(new_object != null, "ProceduralObjectSpawner(%s): _place_objects() - new_object is null" % [name])
			
			new_object.position = Vector2(point, y + object_type.spawn_y_offset)
			bounding_box.position = new_object.position
			
			_add_object(new_object, bounding_box)
			spawn_count += 1
			print_debug("ProceduralObjectSpawner(%s): Spawned object %s at %s" % [name, object_scene.resource_name, new_object.position])
			
			if spawn_count >= max_spawn_count:
				break

func _add_object(node: Node, bounds:Rect2) -> void:
	container.add_child(node)

	# Add the bounding box to the sorted list
	_insert_bounds(bounds)
	
func _get_placement_y_at(bounds: Rect2, object_type : ProceduralObjectContraints, x: float) -> float:
	var center_point_test := _get_ground_position(x)
	if not center_point_test:
		return -1

	var half_width:float = bounds.size.x * 0.5
	var left_point_test := _get_ground_position(x - half_width)
	if not left_point_test:
		return -1
	
	var right_point_test := _get_ground_position(x + half_width)
	if not right_point_test:
		return -1

	var center_point:Vector2 = center_point_test.position
	var left_point:Vector2 = left_point_test.position
	var right_point:Vector2 = right_point_test.position

	# Now need to check if the angle between center_point_test to left and right is within the constraint max angle
	var angle_left:float = absf(rad_to_deg(left_point.angle_to_point(center_point)))
	if angle_left > object_type.max_slant_angle_deg:
		return -1
	var angle_right:float = absf(rad_to_deg(center_point.angle_to_point(right_point)))
	if angle_right > object_type.max_slant_angle_deg:
		return -1
	# also test left to right
	var angle_all:float = absf(rad_to_deg(left_point.angle_to_point(right_point)))
	if angle_all > object_type.max_slant_angle_deg:
		return -1
		
	# Check this doesn't intersect already spawned objects
	if _intersects_existing_spawned(center_point, object_type, bounds):
		return -1

	return center_point.y

func _get_ground_position(x: float) -> Dictionary[String, Vector2]:
	var from:Vector2 = Vector2(x, 0)
	var to:Vector2 = Vector2(x, get_viewport().get_visible_rect().size.y)
	
	var query_params = PhysicsRayQueryParameters2D.create(from, to,
	 Collisions.CompositeMasks.obstacle)
	
	var space_state := get_world_2d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(query_params)

	if !result:
		push_error("ProceduralObjectSpawner(%s): _get_spawn_position could not find y for x=%f" % [name, x])
		return {}
	
	# Should have intersected the terrain
	var collider:Node = result.collider
	if  collider.collision_layer != Collisions.Layers.terrain:
		print_debug("ProceduralObjectSpawner(%s): Ground position: %s collided with non terrain object %s" % [name, result.position, collider.name])
		return {}
	var ground_pos:Vector2 = result.position
	
	return { "position" : ground_pos }

func _find_and_insert_tank_bounds() -> void:
	var tanks: Array[Node] = get_tree().get_nodes_in_group(Groups.Unit)
	print_debug("ProceduralObjectSpawner(%s): found %d tanks in scene" % [name, tanks.size()])
	
	for tank in tanks:
		var bounds:Rect2 = tank.get_rect()
		bounds.position = tank.global_position
		_insert_bounds(bounds)
		
func _insert_bounds(bounds:Rect2) -> void:
	var insertPos:int = _sorted_insert_positions.bsearch_custom(bounds, _bounds_compare)
	_sorted_insert_positions.insert(insertPos, bounds)
	
func _intersects_existing_spawned(pos: Vector2, object_type : ProceduralObjectContraints, bounds:Rect2) -> bool:
	if _sorted_insert_positions.is_empty():
		return false

	bounds.position = pos
	var insertPos:int = _sorted_insert_positions.bsearch_custom(bounds, _bounds_compare)

	# See if placing it here will intersect previous or the next
	# Expand the bounds to include the spacing
	bounds.size.x += object_type.min_spacing

	if insertPos > 0:
		var prev_bounds:Rect2 = _sorted_insert_positions[insertPos - 1]
		if bounds.intersects(prev_bounds):
			return true
	
	if insertPos < _sorted_insert_positions.size():
		var next_bounds:Rect2 = _sorted_insert_positions[insertPos]
		if bounds.intersects(next_bounds):
			return true

	return false
	
func _bounds_compare(a:Rect2, b:Rect2) -> bool:
	return a.position.x < b.position.x

func _get_bounding_box(root: Node) -> Rect2:
	var rect := Rect2()
	var nodes:Array[Node] = [root]
	
	while not nodes.is_empty():
		var node:Node = nodes.pop_back()
		if node.has_method("get_rect") and node.has_method("to_global"):
			var node_rect:Rect2 = node.get_rect()
			node_rect.position = node.to_global(node_rect.position)
			rect = rect.merge(node_rect)
		for child in node.get_children():
			nodes.append(child)
	return rect
