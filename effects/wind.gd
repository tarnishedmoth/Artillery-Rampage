class_name Wind extends Node

const ParticlesGroupName:StringName = &"Wind_CPUParticles2D"

@export_category("Wind")
@export_range(0.0, 1e9, 0.001, "or_greater")
var wind_scale:float = 1.0

@export_category("Wind")
@export_range(-100, 1e9, 1, "or_greater")
var wind_min:int = -100

@export_category("Wind")
@export_range(0.0, 1e9, 1, "or_greater")
var wind_max:int = 100

@export_category("Wind")
@export_range(-1.0, 1.0, 0.01, "or_greater")
var wind_sign_bias:float = 0

@export_category("Wind")
@export_range(0, 1e9, 1, "or_greater")
var max_per_orbit_variance:int = 0

var _variance_delta:int = 0
var _current_variance_amount:int = 0

var wind: Vector2 = Vector2():
	set(value):
		wind = value
		print_debug("WIND(%s): set to %s" % [name, str(value)])
		GameEvents.wind_updated.emit(self)
		_on_wind_updated()
	get:
		return wind

var wind_size:float:
	get:
		# No y component
		return absf(wind.x)

var force: Vector2:
	get:
		return wind * wind_scale
				
var _active_projectile_set: Dictionary[WeaponProjectile, WeaponProjectile] = {}
var _active_particles_set: Array[CPUParticles2D]

func _ready() -> void:
	# Randomize the wind
	wind = Vector2(_randomize_wind(), 0.0)
	# Connect signal for projectiles
	GameEvents.projectile_fired.connect(_on_projectile_fired)
	# Connect signal for particles in group
	get_tree().node_added.connect(_check_and_add_particles)
	# Check for anything set up before we got here.
	for node in get_tree().get_nodes_in_group(ParticlesGroupName):
		_check_and_add_particles(node)

	if max_per_orbit_variance > 0 and wind_max - wind_min > 0:
		print_debug("%s: max_per_orbit_variance=%d - listening for cycles" % [name, max_per_orbit_variance])
		GameEvents.orbit_cycled.connect(_on_orbit_cycled)
		
func _on_orbit_cycled() -> void:
	var new_variance:int = _new_variance()
	if new_variance != 0:
		_variance_delta += new_variance
		_current_variance_amount = new_variance
		print_debug("%s: Orbit Cycled - wind changed by %d: Total Variance=%d" % [name, new_variance, _variance_delta])
		wind = Vector2(wind.x + new_variance, 0.0)

func _randomize_wind() -> int:
	# Increase "no-wind" probability by allowing negative and then clamping to zero if the random number is < 0
	return max(randi_range(wind_min, wind_max), 0) * (1 if randf() <= 0.5 + wind_sign_bias * 0.5 else -1)

func _new_variance() -> int:
	var min_value:int = maxi(-max_per_orbit_variance, wind_min - roundi(wind.x))
	var max_value:int = mini(max_per_orbit_variance, wind_max - roundi(wind.x))

	if _variance_delta > 0:
		max_value -= _variance_delta
	elif _variance_delta < 0:
		min_value -= _variance_delta

	var new_variance:int = randi_range(min_value, max_value)

	print_debug("%s: Variance changed from %d -> %d from [%d, %d]" % [name, _current_variance_amount, new_variance, min_value, max_value])

	return new_variance

func _physics_process(delta: float) -> void:
	if _active_projectile_set.is_empty():
		return
	_apply_wind_to_active_projectiles(delta)

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	# Need to bind the extra projectile argument to connect
	projectile.completed_lifespan.connect(_on_projectile_destroyed.bind(projectile))
	_active_projectile_set[projectile] = projectile

	#print_debug("%s: on_projectile_fired: %s - tracking=%d" % [name, projectile.name, _active_projectile_set.size()])

func _on_projectile_destroyed(projectile: WeaponProjectile) -> void:
	_active_projectile_set.erase(projectile)
	#print_debug("%s: on_projectile_destroyed: %s - tracking=%d" % [name, projectile.name, _active_projectile_set.size()])
	
func _on_particles_group_member_freed(member:CPUParticles2D) -> void:
	_active_particles_set.erase(member)
	
func _apply_wind_to_active_projectiles(delta: float) -> void:
	for projectile in _active_projectile_set:
		if is_instance_valid(projectile) and projectile.is_affected_by_wind:
			projectile.apply_central_force(force * delta)
			
func _apply_wind_to_particles(group:Array) -> void:
	var windspeed:float = wind.x * 0.8
	for member in group:
		if member.gravity.x != windspeed:
			member.gravity.x = windspeed

func _check_and_add_particles(node: Node) -> void:
	if node is CPUParticles2D:
		if node.is_in_group(ParticlesGroupName):
			# Use a meta tag for tracking as its more lightweight than an array comparison.
			const meta_string_name:StringName = &"AddedToWindParticlesGroup"
			if not meta_string_name in node.get_meta_list():
				# Add to our internal array for updates
				_active_particles_set.append(node)
				# Set the meta tag
				node.set_meta(meta_string_name, true)
				# Connect the exiting signal to remove it from our array
				node.tree_exiting.connect(_on_particles_group_member_freed.bind(node))
				# Apply wind to the particles.
				_apply_wind_to_particles([node])
				print_debug("WIND: Found and added new group member! - ", node)

func _on_wind_updated() -> void:
	_apply_wind_to_particles(_active_particles_set)
