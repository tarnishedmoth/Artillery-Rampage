class_name ShatterableObjectBody extends RigidBody2D

@onready var _mesh: Polygon2D = $Mesh
@onready var _collision: CollisionPolygon2D = $Collision
@onready var _poly_ops:DestructiblePolyOperations = $DestructiblePolyOperations

@export var use_mesh_as_collision:bool = true

@export var min_shatter_area:float = 250
@export_range(0, 1, 0.01) var max_shatter_area_fract: float = 1/3.0

@export var min_body_impulse:float = 100
@export var max_body_impulse:float = 200

@export var min_velocity_angle_dev: float = 0
@export var max_velocity_angle_dev: float = 90

@export var max_shatter_divisions: int = 1

@export var max_lifetime: float = 30.0

@export var min_mass: float = 50

@export var shattered_pieces_should_collide_with_tank: bool = false

@export var stuck_detector_scene: PackedScene

var shatter_iteration: int = 0

var _init_poly:PackedVector2Array = []
var _init_owner: Node

@export
var density: float = 0.0
var area: float = 0.0

signal ready_finished(body: ShatterableObjectBody)

# Note that should apply the offset position to the root position rather than the mesh position otherwise
# will get rotation about the body center and this will cause a "hinge" rotation that is probably not desired

# TODO: Detect if get stuck inside something as a failsafe in the _physics_process
# This will be a separate sub-component added to this object and any other rigid bodies we want to anihilate if spawn stuck

func _ready() -> void:
	if SceneManager.is_precompiler_running:
		return

	if not _init_poly.is_empty():
		print_debug("%s - initializing from specified poly of size=%d" % [name, _init_poly.size()])
		_mesh.polygon = _init_poly
		_recenter_polygon()
	if _init_owner:
		owner = _init_owner
	
	if is_zero_approx(area):
		area = TerrainUtils.calculate_polygon_area(_mesh.polygon)	
	if density > 0 and area > 0:
		mass = maxf(density * area, min_mass)
	elif area > 0 and mass > 0:
		density = mass / area
	else:
		push_warning("ShatterableObjectBody(%s) - Polygon area is zero, setting density to 1" % [name])
		density = 1
		mass = min_mass

	if use_mesh_as_collision:
		_collision.set_deferred("position", _mesh.position)
		_collision.set_deferred("polygon", _mesh.polygon)
	if shatter_iteration > 0 and max_lifetime > 0:
		print_debug("%s - shatter iteration %d, setting lifetime to %f" % [name, shatter_iteration, max_lifetime])
		var timer: Timer = Timer.new()
		timer.one_shot = true
		timer.autostart = true
		timer.wait_time = max_lifetime
		timer.timeout.connect(_on_lifetime_ended)
		add_child(timer)
	
	ready_finished.emit(self)

func get_area() -> float:
	return area

func get_rect() -> Rect2:
	var bounds:Rect2 = TerrainUtils.get_polygon_bounds(_mesh.polygon)
	bounds.position += to_local(_mesh.global_position)
	return bounds

func _recenter_polygon() -> void:
	# Should recenter the polygon about its new center of mass (centroid)
	var centroid: Vector2 = TerrainUtils.polygon_centroid(_mesh.polygon)
	# We want the centroid to be the rigid body center
	position = Vector2.ZERO
	_mesh.position = -centroid
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO

func damage(projectile: WeaponPhysicsContainer, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	owner.damage(self, projectile, contact_point, poly_scale)
	
func shatter(projectile: WeaponPhysicsContainer, _destructible_poly_global: PackedVector2Array) -> Array[Node2D]:
	return await shatter_with_velocity(projectile.last_recorded_linear_velocity)

func shatter_with_velocity(impact_velocity: Vector2) -> Array[Node2D]:
	var new_bodies: Array[Node2D] = []

	if shatter_iteration < max_shatter_divisions:
		set_deferred("freeze", true)
		await get_tree().physics_frame

		new_bodies = _create_shatter_nodes(impact_velocity)
	else:
		print_debug("%s - shatter iteration limit reached" % [name])
	delete()

	return new_bodies

## Creates nodes in the shattered result
## Can override to change the poly shatter behavior to return other kinds of nodes
func _create_shatter_nodes(impact_velocity: Vector2) -> Array[Node2D]:
	var new_bodies: Array[Node2D] = []
	
	var new_polys: Array[PackedVector2Array] = _create_shatter_polys()
	var poly_separation: PackedVector2Array = _poly_ops.calculate_shatter_poly_separation(new_polys, _mesh.global_transform)
	
	new_bodies.resize(new_polys.size())

	var impact_velocity_dir: Vector2 = _compute_impact_velocity_dir(impact_velocity)

	for i in range(new_polys.size()):
		var new_poly: PackedVector2Array = new_polys[i]
		new_bodies[i] = _create_body_from_poly(new_poly, impact_velocity_dir, poly_separation[i])
	return new_bodies

func _on_lifetime_ended() -> void:
	# We only fade out on the lifetime ended delete case 
	# as when pieces shatter into sub-pieces we want to delete immediately
	if OS.is_debug_build():
		print_debug("ShatterableObjectBody(%s) - fade out + delete" % [name])
	var tweener = Juice.fade_out(self)
	await tweener.finished
	delete()

func delete() -> void:
	print_debug("ShatterableObjectBody(%s) - delete" % [name])
	if is_instance_valid(owner):
		owner.body_deleted.emit(self)
	
	queue_free.call_deferred()

func _create_shatter_polys() -> Array[PackedVector2Array]:
	var max_area: float = maxf(min_shatter_area, area * max_shatter_area_fract)
	return _poly_ops.shatter(_mesh.polygon, min_shatter_area, max_area)

func _create_body_from_poly(poly: PackedVector2Array, impact_velocity_dir: Vector2, position_offset: Vector2) -> Node2D:
	var new_instance: Node2D = _new_node_from_poly(poly, position_offset)
	
	if new_instance is RigidBody2D:
		_apply_impulse_to_new_body(new_instance, poly, impact_velocity_dir)
		_adjust_new_body_collision(new_instance)

	return new_instance

func _compute_impact_velocity_dir(impact_velocity: Vector2) -> Vector2:
	return impact_velocity.normalized() if not impact_velocity.is_equal_approx(Vector2.ZERO) else MathUtils.get_rand_vector2_dir()

## Overridable by subclasses to change which body actually spawned in different circumstances
## By default creates a duplicate of itself with adjusted poly and mass
func _new_node_from_poly(poly: PackedVector2Array, position_offset: Vector2) -> Node2D:
	var new_instance: ShatterableObjectBody = duplicate()
	
	# Have to wait for the instance to enter the tree before accessing polygon on mesh
	# so set it on an instance variable and _ready will set the mesh polygon
	new_instance._init_poly = poly
	# owner must be in tree so wait until next frame once it is in tree
	new_instance._init_owner = owner
	
	new_instance.shatter_iteration = shatter_iteration + 1
	
	new_instance.density = density
	
	new_instance.position = position + position_offset
	new_instance.rotation = rotation

	var stuck_detector := _create_stuck_detector()
	if stuck_detector:
		# Child nodes are null until the node is added to the tree 
		# so wait for ready
		new_instance.ready_finished.connect(func(_i):
			stuck_detector.body = new_instance
			stuck_detector.mesh = new_instance._mesh
			_add_stuck_detector(new_instance, stuck_detector)
		)
	
	return new_instance
	
func _add_stuck_detector(new_instance:Node2D, stuck_detector: StuckDetector) -> void:
	if OS.is_debug_build():
		print_debug("ShatterableObjectBody(%s) - adding stuck detector to %s" % [name, new_instance.name])
	stuck_detector.body_stuck.connect(_on_stuck)
	new_instance.add_child(stuck_detector)

static func _on_stuck(detector: StuckDetector) -> void:
	var parent:Node2D = detector.get_parent()

	print_debug("Body %s is stuck, deleting" % [parent.name])
	if parent.has_method("delete"):
		parent.delete()
	else:
		parent.queue_free()

func _create_stuck_detector() -> StuckDetector:
	if not stuck_detector_scene:
		return null
	var stuck_detector:StuckDetector = stuck_detector_scene.instantiate() as StuckDetector
	if not stuck_detector:
		push_error("ShatterableObjectBody(%s) - unable to instantiate stuck detector from %s" % [name, stuck_detector_scene.resource_path])
		return null
	return stuck_detector

func _apply_impulse_to_new_body(new_instance:RigidBody2D, poly: PackedVector2Array, impact_velocity_dir: Vector2) -> void:
	var impulse:Vector2 = _randomize_impact_velocity_dir(impact_velocity_dir) * randf_range(min_body_impulse, max_body_impulse)
	var location: Vector2 = _get_random_point_in_or_near_poly(poly)
	new_instance.apply_impulse(impulse, location)
	
func _adjust_new_body_collision(new_instance:RigidBody2D) -> void:
	# Don't have the pieces collide with the tank if configured
	if not shattered_pieces_should_collide_with_tank:
		Collisions.add_exception_for_layer_and_group(new_instance, Collisions.Layers.tank, Groups.Unit)
	
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

func _to_string() -> String:
	return name
