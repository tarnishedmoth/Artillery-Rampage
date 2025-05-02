class_name ProceduralObjectSpawner extends Node2D

@export var objects:Array[ProceduralObjectContraints] = []
@onready var container:Node = $Container

@export var spawn_screen_deadzone: float = 20.0

# Need to wait for the terrain to finish building before doing raycasts
const spawn_delay:float = 0.2

var _spawned_objects:Dictionary[int, Node] = {}

func _ready() -> void:
	# TODO: Maybe place after units spawned?
	await get_tree().create_timer(spawn_delay).timeout

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

	# Try to generate objects starting at opposite ends of the screen and meet in middle
	var bounds:Rect2 = get_viewport().get_visible_rect()
	var half_width:float = bounding_box.size.x / 2

	var start_x:float = bounds.position.x + spawn_screen_deadzone + half_width
	var end_x:float = bounds.position.x + bounds.size.x - spawn_screen_deadzone - half_width
	var step:float = bounding_box.size.x + object_type.min_spacing

	var points: Array[float] = []
	var num_points:int = floori((end_x - start_x) / step)
	points.resize(num_points)
	for i in num_points:
		points[i] = start_x + (i - 1) * step + bounding_box.size.x + randf() * object_type.min_spacing

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
			_add_object(new_object)
			spawn_count += 1
			print_debug("ProceduralObjectSpawner(%s): Spawned object %s at %s" % [name, object_scene.resource_name, new_object.position])
			
			if spawn_count >= max_spawn_count:
				break

func _add_object(node: Node) -> void:
	container.add_child(node)
	_spawned_objects[node.get_instance_id()] = node
	
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
	if _intersects_existing_spawned(center_point, bounds):
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
		push_error("ProceduralObjectSpawner(%s): _get_spawn_position could not find y - x=%f" % [name, x])
		return {}
		
	# This doesn't work as physics engine hasn't processed the new nodes yet
	# Make sure objects not spawning on top of each other
	#if _is_part_of_spawned(result.collider):
	#	return {}
	var ground_pos:Vector2 = result["position"]
	
	return { "position" : ground_pos }

func _is_part_of_spawned(node: Node) -> bool:
	while node:
		if node.get_instance_id() in _spawned_objects:
			return true
		node = node.get_parent()
	return false

func _intersects_existing_spawned(pos: Vector2, bounds:Rect2) -> bool:
	bounds.position = pos
	for node_id in _spawned_objects:
		var node:Node = _spawned_objects[node_id]
		var node_rect:Rect2 = _get_bounding_box(node)
		if bounds.intersects(node_rect):
			return true
	return false
	
func _get_bounding_box(root: Node) -> Rect2:
	var rect := Rect2()
	var nodes:Array[Node] = [root]
	
	while not nodes.is_empty():
		var node:Node = nodes.pop_back()
		if node.has_method("get_rect"):
			var node_rect:Rect2 = node.get_rect()
			node_rect.position = node.to_global(node_rect.position)
			rect = rect.merge(node_rect)
		for child in node.get_children():
			nodes.append(child)
	return rect
