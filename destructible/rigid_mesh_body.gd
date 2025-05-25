# TODO: Refactor ShatterableObjectChunk to extend this
class_name RigidMeshBody extends RigidBody2D

@onready var mesh: Polygon2D = $Mesh
@onready var _collision: CollisionPolygon2D = $CollisionPolygon
@onready var _collision_shape:CollisionShape2D = $CollisionShape

@export var use_mesh_as_collision:bool = true
@export var max_lifetime: float = 30.0
@export var min_mass: float = 50
@export var recenter_polygon:bool = true 

@export
var density: float = 0.0
var area: float = 0.0

var _init_poly:PackedVector2Array = []
var _init_owner: Node

@export 
var invoke_ready: bool = true

# Note that should apply the offset position to the root position rather than the mesh position otherwise
# will get rotation about the body center and this will cause a "hinge" rotation that is probably not desired

func _ready() -> void:
	if not invoke_ready or SceneManager.is_precompiler_running:
		return
	
	if not _init_poly.is_empty():
		print_debug("%s - initializing from specified poly of size=%d" % [name, _init_poly.size()])
		mesh.polygon = _init_poly
		recenter_polygon = true
	if _init_owner:
		owner = _init_owner

	if recenter_polygon:
		_recenter_polygon()

	if is_zero_approx(area):
		area = TerrainUtils.calculate_polygon_area(mesh.polygon)	
	if density > 0 and area > 0:
		mass = maxf(density * area, min_mass)
	elif area > 0 and mass > 0:
		density = mass / area
	else:
		push_warning("ShatterableObjectBody(%s) - Polygon area is zero, setting density to 1" % [name])
		density = 1
		mass = min_mass

	if use_mesh_as_collision:
		(func() -> void:
			_collision.disabled = false
			_collision_shape.disabled = true
			
			_collision.position = mesh.position
			_collision.polygon = mesh.polygon
		).call_deferred()
	else: # Use the collision shape
		(func() -> void:
			_collision_shape.disabled = false
			_collision.disabled = true
		).call_deferred()
		
	if max_lifetime > 0:
		print_debug("%s - Setting lifetime to %f" % [name, max_lifetime])
		var timer: Timer = Timer.new()
		timer.one_shot = true
		timer.autostart = true
		timer.wait_time = max_lifetime
		timer.timeout.connect(delete)
		add_child(timer)

func get_area() -> float:
	return area

func get_rect() -> Rect2:
	var bounds:Rect2 = TerrainUtils.get_polygon_bounds(mesh.polygon)
	bounds.position += to_local(mesh.global_position)
	return bounds

func _recenter_polygon() -> void:
	# Should recenter the polygon about its new center of mass (centroid)
	var centroid: Vector2 = TerrainUtils.polygon_centroid(mesh.polygon)
	# We want the centroid to be the rigid body center
	position = Vector2.ZERO
	mesh.position = -centroid
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO

func delete() -> void:
	print_debug("ShatterableObjectBody(%s) - fade out + delete" % [name])
	await Juice.fade_out(self, Juice.SMOOTH, Color.TRANSPARENT).finished
	if is_instance_valid(owner) and owner.has_signal("body_deleted"):
		owner.body_deleted.emit(self)
		
	queue_free.call_deferred()
