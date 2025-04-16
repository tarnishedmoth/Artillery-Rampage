class_name ShatterableObjectBody extends RigidBody2D

@onready var _mesh: Polygon2D = $Mesh
@onready var _collision: CollisionPolygon2D = $Collision
@onready var _poly_ops:DestructiblePolyOperations = $DestructiblePolyOperations

@export var use_mesh_as_collision:bool = true

@export var min_shatter_area:float = 250
@export_range(0, 1, 0.01) var max_shatter_area_fract: float = 1/3.0

@export var min_body_linear_speed: float = 50
@export var max_body_linear_speed: float = 200

@export var min_body_angular_speed: float = 0
@export var max_body_angular_speed: float = 360

@export var min_velocity_angle_dev: float = 0
@export var max_velocity_angle_dev: float = 90

@export var max_shatter_divisions: int = 1

@export var max_lifetime: float = 30.0

@export var min_mass: float = 50

@export var shattered_pieces_should_collide_with_tank: bool = false

var shatter_iteration: int = 0

var _init_poly:PackedVector2Array = []
var _init_owner: Node

var density: float = 0.0
var area: float = 0.0

# Note that should apply the offset position to the root position rather than the mesh position otherwise
# will get rotation about the body center and this will cause a "hinge" rotation that is probably not desired

func _ready() -> void:
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
		
	if use_mesh_as_collision:
		_collision.set_deferred("position", _mesh.position)
		_collision.set_deferred("polygon", _mesh.polygon)
	if shatter_iteration > 0 and max_lifetime > 0:
		print_debug("%s - shatter iteration %d, setting lifetime to %f" % [name, shatter_iteration, max_lifetime])
		var timer: Timer = Timer.new()
		timer.one_shot = true
		timer.autostart = true
		timer.wait_time = max_lifetime
		timer.timeout.connect(delete)
		add_child(timer)

func _recenter_polygon() -> void:
	# Should recenter the polygon about its new center of mass (centroid)
	var centroid: Vector2 = TerrainUtils.polygon_centroid(_mesh.polygon)
	# We want the centroid to be the rigid body center
	position = Vector2.ZERO
	_mesh.position = -centroid
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO

func damage(projectile: WeaponProjectile, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	owner.damage(self, projectile, contact_point, poly_scale)
	
func shatter(projectile: WeaponProjectile, destructible_poly_global: PackedVector2Array) -> Array[Node2D]:
	# TODO: Split current polygon into smaller pieces as new bodies
	# Should set a lifetime on smaller pieces to auto-delete or go to sleep permanently after a given interval
	# If we want ot be able to shatter again we return another instance of ShatterableObjectBody; otherwise, return a simple RigidBody2D or event a 
	# StaticBody2D or just a particle effect that expires and deletes itself after a period
	# TODO: Use velocity of weapon projectile to determine how pieces fly off
	var new_bodies: Array[Node2D] = []

	if shatter_iteration < max_shatter_divisions:
		var new_polys: Array[PackedVector2Array] = _create_shatter_polys(projectile, destructible_poly_global)
		new_bodies.resize(new_polys.size())

		var impact_velocity_dir: Vector2 = projectile.last_recorded_linear_velocity.normalized()

		for i in range(new_polys.size()):
			var new_poly: PackedVector2Array = new_polys[i]
			new_bodies[i] = _create_body_from_poly(new_poly, impact_velocity_dir)
	else:
		print_debug("%s - shatter iteration limit reached" % [name])
	delete()

	return new_bodies

func delete() -> void:
	print_debug("ShatterableObjectBody(%s) - delete" % [name])
	owner.body_deleted.emit(self)
	
	queue_free.call_deferred()

func _create_shatter_polys(_projectile: WeaponProjectile, _destructible_poly_global: PackedVector2Array) -> Array[PackedVector2Array]:
	var max_area: float = maxf(min_shatter_area, area * max_shatter_area_fract)
	return _poly_ops.shatter(_mesh.polygon, min_shatter_area, max_area)

func _create_body_from_poly(poly: PackedVector2Array, impact_velocity_dir: Vector2) -> ShatterableObjectBody:
	var new_instance: ShatterableObjectBody = duplicate()
	
	# Have to wait for the instance to enter the tree before accessing polygon on mesh
	# so set it on an instance variable and _ready will set the mesh polygon
	new_instance._init_poly = poly
	# owner must be in tree so wait until next frame once it is in tree
	new_instance._init_owner = owner
	
	new_instance.shatter_iteration = shatter_iteration + 1
	
	new_instance.density = density
	
	new_instance.position = position
	new_instance.rotation = rotation
	new_instance.linear_velocity = _randomize_impact_velocity_dir(impact_velocity_dir) * randf_range(min_body_linear_speed, max_body_linear_speed)
	new_instance.angular_velocity = deg_to_rad(randf_range(min_body_angular_speed, max_body_angular_speed))

	# Don't have the pieces collide with the tank if configured
	if not shattered_pieces_should_collide_with_tank:
		new_instance.collision_mask &= ~Collisions.Layers.tank
		# Layers and masks could still match on the tank side so get all the units in group and add instance exception
		for unit in get_tree().get_nodes_in_group(Groups.Unit):
			if unit is Tank:
				unit.tankBody.add_collision_exception_with(new_instance)

	return new_instance

func _randomize_impact_velocity_dir(impact_velocity_dir: Vector2) -> Vector2:
	var angle_dev: float = deg_to_rad(randf_range(min_velocity_angle_dev, max_velocity_angle_dev))
	var random_angle: float = angle_dev * MathUtils.randf_sgn()
	return impact_velocity_dir.rotated(random_angle)

func _to_string() -> String:
	return name
