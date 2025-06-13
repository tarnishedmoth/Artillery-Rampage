class_name Wind extends Node

const ParticlesGroupName:StringName = &"Wind_CPUParticles2D"

## Scales the wind force per the wind scalar amount. Use to tune the strength.
@export_category("Wind")
@export_range(0.0, 1e9, 0.001, "or_greater")
var wind_scale:float = 1.0

## Minimum wind scalar value. Use a value < 0 to increase probability of no wind.
## E.g. if wind_min = -100 and wind_max = 100 then there is a 50% chance of no wind
## as values < 0 are clamped to 0.
@export_category("Wind")
@export_range(-100, 1e9, 1, "or_greater")
var wind_min:int = -100

@export_category("Wind")
@export_range(0.0, 1e9, 1, "or_greater")
var wind_max:int = 100

## Biases the wind to left or right. A value of zero has equal left and right probability.
## A value of -1 would bias the wind 100% to the left and 1 would be 100% to the right.
@export_category("Wind")
@export_range(-1.0, 1.0, 0.01, "or_greater")
var wind_sign_bias:float = 0

## Makes the wind change by a random amount each turn orbit anchored to the original wind value.
## E.g if the wind started at 25 and has a min value of 10 and max value of 50 and the variance is 20 then
## the wind can go anywhere between [10,45] since the left side gets clamped due to min wind restriction
## The max variance is 2 * wind_max if we have wind_min of 0 and wind_max of 100.
@export_category("Wind")
@export_range(0, 1e9, 1, "or_greater")
var max_per_orbit_variance:int = 0:
	set(value):
		if max_per_orbit_variance == value:
			return
		max_per_orbit_variance = value
		# Only need to do if we are already in the tree and this being changed during gameplay
		if is_inside_tree():
			# Wait until other values potentially changed since wind only changed per orbit
			_update_variance.call_deferred()
	get:
		return max_per_orbit_variance

var _wind_range:Vector2i

var wind: Vector2 = Vector2():
	set(value):
		var changed:bool = not wind.is_equal_approx(value)
		# Still need to fire the update event on first set
		wind = value
		print_debug("WIND(%s): set to %s" % [name, str(value)])
		GameEvents.wind_updated.emit(self)
		_on_wind_updated()
		
		# Only need to do if we are already in the tree and this being changed during gameplay
		if changed and get_parent():
			# Wait until other values potentially changed since wind only changed per orbit
			_update_variance.call_deferred() 
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
	randomize_wind()
	# Connect signal for projectiles
	GameEvents.projectile_fired.connect(_on_projectile_fired)
	# Connect signal for particles in group
	get_tree().node_added.connect(_check_and_add_particles)
	# Check for anything set up before we got here.
	for node in get_tree().get_nodes_in_group(ParticlesGroupName):
		_check_and_add_particles(node)
	_update_variance()
		
func _on_turn_orbit_cycled() -> void:
	_vary_wind()

func randomize_wind() -> void:
	wind = Vector2(_calculate_randomized_wind(), 0.0)

func _calculate_randomized_wind() -> int:
	# Increase "no-wind" probability by allowing negative and then clamping to zero if the random number is < 0
	return maxi(randi_range(wind_min, wind_max), 0) * (1 if randf() <= 0.5 + wind_sign_bias * 0.5 else -1)

func _update_variance() -> void:
	if max_per_orbit_variance > 0 and wind_max > 0:
		print_debug("%s: max_per_orbit_variance=%d - listening for cycles" % [name, max_per_orbit_variance])
		_compute_variance_range()

		if not GameEvents.turn_orbit_cycled.is_connected(_on_turn_orbit_cycled):
			GameEvents.turn_orbit_cycled.connect(_on_turn_orbit_cycled)
	elif GameEvents.turn_orbit_cycled.is_connected(_on_turn_orbit_cycled):
			print_debug("%s: Disconnecting turn orbit cycled since wind will no longer vary" % name)
			GameEvents.turn_orbit_cycled.disconnect(_on_turn_orbit_cycled)

func _vary_wind() -> void:
	var current_wind:int = roundi(wind.x)

	var new_wind:int = randi_range(
		maxi(current_wind - max_per_orbit_variance, _wind_range.x),
		mini(current_wind + max_per_orbit_variance, _wind_range.y)
	)

	print_debug("%s: Changing wind from %d to %d in range %s with max variance %d" % [name, roundi(wind.x), new_wind, str(_wind_range), max_per_orbit_variance])

	wind = Vector2(new_wind, 0.0)

func _compute_variance_range() -> void:
	var starting_wind:int = roundi(wind.x)
	
	_wind_range.x = _clamp_wind_max_value(starting_wind - max_per_orbit_variance)
	_wind_range.y = _clamp_wind_max_value(starting_wind + max_per_orbit_variance)
	_wind_range = _clamp_wind_min_value(starting_wind, _wind_range)

	# Make sure x < y
	if _wind_range.x > _wind_range.y:
		_wind_range = Vector2i(_wind_range.y, _wind_range.x)

	print_debug("%s: Wind can vary in range %s" % [name, str(_wind_range)])	

# Clamp to fall within wind_min and wind_max
func _clamp_wind_max_value(value:int) -> int:
	var sgn:int = signi(value)
	# Make positive
	value *= sgn
	value = mini(value, wind_max)

	return value * sgn

func _clamp_wind_min_value(starting_wind:int, value:Vector2i) -> Vector2i:
	if wind_min <= 0:
		return value

	# Need to clamp one end of the wind to min depending on the sign
	if value.x < 0 and value.y > 0:
		if starting_wind >= 0: # Clamp minimum to a positive value
			value.x = mini(wind_min, starting_wind)
		else: #Clamp y to a negative value
			value.y = -wind_min
	elif value.x < 0: # value.y < 0
		value.y = -maxi(-value.y, wind_min)
	else: #value.x > 0 and value.y > 0
		value.x = maxi(value.x, wind_min)

	return value

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
				if OS.is_stdout_verbose():
					print_debug("WIND: Found and added new group member! - ", node)

func _on_wind_updated() -> void:
	_apply_wind_to_particles(_active_particles_set)
