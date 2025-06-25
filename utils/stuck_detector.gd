class_name StuckDetector extends Node

### This script detects if a RigidBody2D is stuck in place due to jittering.
@export var body: RigidBody2D
@export var mesh: Polygon2D

## Threshold of velocity for jitter detection.
## If the body is moving slower than this, it is considered still.
@export var jitter_threshold: float = 100.0

## Threshold of position change for stillness detection.
## If the body has moved less than this value, it is considered still.
@export var stillness_threshold: float = 1.0

## Number of frames to consider for jitter detection.
@export_range(1, 300) var jitter_frame_limit: int = 30

### If set to a positive value, the detector will stop after this many seconds.
@export var detection_max_lifetime:float = 5

@export var check_centroid_collision:bool = true
@export var centroid_collision_mask:int = Collisions.CompositeMasks.obstacle

@export var enable_on_ready:bool = false

signal body_stuck(detector: StuckDetector)

var _jitter_count := 0

var _position_buffer: PackedVector2Array
var _speed_buffer: PackedFloat32Array
var _num_samples:int

var _pos_index:int = 0
var _cycled:bool = false
var _timer:Timer
var _ready_run:bool = false

var centroid:Vector2

func _ready():
	if SceneManager.is_precompiler_running:
		return
	_ready_run = true
	set_physics_process(false)
	if enable_on_ready:
		_enable()

var enable:bool = enable_on_ready:
	get:
		return enable
	set(value):
		if value == enable:
			return
		if not value:
			_disable()
			return
		if not _ready_run:
			enable_on_ready = true
		else:
			_enable()
		
func _enable() -> void:
	if not body:
		push_error("%s: No body assigned to StuckDetector." % name)
		return

	if check_centroid_collision:
		if not mesh:
			push_error("%s: No mesh assigned to StuckDetector." % name)
			return
		# Special case for rigid body mesh as this is already computed
		if body is RigidMeshBody:
			centroid = body.centroid_local
		else:
			centroid = TerrainUtils.polygon_centroid(mesh.polygon)
	elif get_parent() is not Node2D:
		push_error("%s: StuckDetector must be a child of a Node2D to check centroid collision." % name)
		return

	_num_samples = jitter_frame_limit + 1
	_position_buffer.resize(_num_samples)
	_speed_buffer.resize(_num_samples)

	if detection_max_lifetime > 0:
		if not _timer:
			_timer = Timer.new()
			_timer.timeout.connect(_on_lifetime_ended)
			_timer.wait_time = detection_max_lifetime
			_timer.one_shot = true
			_timer.autostart = true
			add_child(_timer)
		else:
			_timer.start()

	set_physics_process(true)

func _disable() -> void:
	if _timer:
		_timer.stop()
	set_physics_process(false)

func _on_lifetime_ended() -> void:
	print_debug("%s: Stuck detector lifetime ended on %s" % [name, body.name])
	queue_free()

func _physics_process(_delta):
	_add_data_points()
	if not _cycled:
		return

	var pos_change := _get_total_position_delta()
	var speed := _get_average_speed()

	if pos_change < stillness_threshold and speed > jitter_threshold and _is_body_center_in_collision():
		_jitter_count += 1
	else:
		_jitter_count = 0

	if _jitter_count >= jitter_frame_limit:
		body_stuck.emit(self)
		_jitter_count = 0

func _add_data_points() -> void:
	var current_index:int = _pos_index
	_position_buffer[current_index] = body.position
	_speed_buffer[current_index] = body.linear_velocity.length()

	_pos_index = (_pos_index + 1) % _num_samples
	if _pos_index == 0:
		_cycled = true

func _get_total_position_delta() -> float:
	var total_delta:Vector2 = _position_buffer[-1] - _position_buffer[0]
	return total_delta.length()

func _get_average_speed() -> float:
	var total_speed:float = 0.0
	for speed in _speed_buffer:
		total_speed += speed
	return total_speed / _speed_buffer.size()

func _is_body_center_in_collision() -> bool:
	# Return true here if feature not enabled as it is a filter on jitter
	if not check_centroid_collision:
		return true

	var parent:Node2D = body.get_parent() as Node2D
	if not parent:
		return true

	var space_state := parent.get_world_2d().direct_space_state

	var global_transform:Transform2D = mesh.global_transform
	var position:Vector2 = global_transform * centroid
	
	var query_params := PhysicsPointQueryParameters2D.new()
	query_params.collide_with_areas = false
	query_params.collide_with_bodies = true
	query_params.collision_mask = centroid_collision_mask
	query_params.position = global_transform * centroid

	var result:Array[Dictionary] = space_state.intersect_point(query_params)
	var in_collision:bool = not result.is_empty()
	
	if OS.is_stdout_verbose():
		print_verbose("%s: parent %s at %s with body=%s in collision=%s" % [name, parent.name, str(position), body.name, str(in_collision)])

	return in_collision
