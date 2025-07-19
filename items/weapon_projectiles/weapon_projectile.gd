class_name WeaponProjectile extends RigidBody2D

#TODO: We might not need the Overlap if we only have the weapon projectile interact with Area2D's and not other physics bodies

enum DamageFalloffType
{
	Constant,
	Linear,
	InverseSquare
}

class CollisionResult:
	var game_time_seconds:float
	var global_position: Vector2
	var collider: Node2D

signal completed_lifespan(projectile:WeaponProjectile) ## Tracked by Weapon class


# The idea here is that we are using RigidBody2D for the physics behavior
# and the Area2D as the overlap detection for detecting hits

@export var color: Color = Color.BLACK

## Self destroys once this time has passed.[br]
## When [member kill_after_turns_elapsed] is used, this time emits [signal completed_lifespan].
@export var max_lifetime: float = 10.0
@export_range(0,99) var kill_after_turns_elapsed:int = 0 ## If >0, destroys after turns passed.
@export var kill_after_turns_elapsed_count_only_self_turns:bool = true ## Related to [member kill_after_turns_elapsed].
@export var is_affected_by_wind:bool = true ## Whether or not [Wind] tracks and applies forces to this object.
## Indicate whether this projectile should destroy itself after an interaction.
## See [method disarm] and [method arm] to change the state at runtime.
@export var should_explode_on_impact:bool = true
var run_collision_logic:bool = true ## Whether to affect damageables & destructibles on collision. See [method arm] and [method disarm].

@export var explosion_to_spawn:PackedScene
@export var rescale_explosion:Vector2 = Vector2(1.0,1.0)

@export var upgrades: Array[ModProjectile] ## For upgrades and nerfs at runtime

@export var damage_falloff_type: DamageFalloffType = DamageFalloffType.Linear
@export var min_falloff_distance: float = 10:
	get: return min_falloff_distance*falloff_distance_multiplier
@export var max_falloff_distance: float = 60:
	get: return max_falloff_distance*falloff_distance_multiplier
@export var falloff_distance_multiplier: float = 1.0 # ModProjectile

@export var min_damage: float = 10:
	get: return min_damage * damage_multiplier
@export var max_damage: float = 100:
	get: return max_damage * damage_multiplier
@export var damage_multiplier: float = 1.0 # ModProjectile

#@export_category("Damage")
#@export var last_collider_time_tolerance: float = 0.1

@export_category("Destructible")
@export var destructible_scale_multiplier:Vector2 = Vector2(10 , 10):
	get: return destructible_scale_multiplier*destructible_scale_multiplier_scalar
@export var destructible_scale_multiplier_scalar:float = 1.0 # ModProjectile

var calculated_hit: bool
var destroyed:bool

var owner_tank: Tank;
var source_weapon: Weapon # The weapon we came from
var firing_container
var destructible_component:CollisionPolygon2D

var _turns_since_spawned:int = 0

#func set_spawn_parameters(in_owner_tank: Tank, power:float, angle:float):
	#self.owner_tank = in_owner_tank
	#linear_velocity = Vector2.from_angle(angle) * power * power_velocity_mult
	
var last_collision:CollisionResult
# Avoid problems with game pauses as _integrate_forces is called
# before on_body_entered and we only need to read the result then
var current_collision:CollisionResult

var last_recorded_linear_velocity:Vector2

## Post Processing Effects
@export_group("Effects")
@export var post_processing_scene: PackedScene

func _ready() -> void:
	connect("body_entered", on_body_entered)
	if has_node('Destructible'):
		destructible_component = get_node('Destructible')
		
	if kill_after_turns_elapsed > 0:
		GameEvents.turn_started.connect(_on_turn_started)
		_emit_completed_lifespan_without_destroying(max_lifetime) # Relinquish turn control
	elif max_lifetime > 0.0: destroy_after_lifetime()
	
	if modulate_enabled():
		modulate = color

	apply_all_mods() # This may not be desired but it probably is. If the weapon's stats are retained across matches, this could double the effect unintentionally
	
	GameEvents.projectile_fired.emit(self)
	
func modulate_enabled() -> bool:
	return true
	
func set_sources(tank:Tank,weapon:Weapon) -> void:
	owner_tank = tank
	source_weapon = weapon
	if explosion_to_spawn:
		firing_container = _get_container()
		
## Sets the projectile to run collision detection code and maybe explode after.
func arm(to_explode:bool = should_explode_on_impact):
	run_collision_logic = true
	should_explode_on_impact = to_explode
	if calculated_hit: calculated_hit = false
func disarm():
	run_collision_logic = false

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Store any collision results for later access
	if state.get_contact_count() >= 1 and SceneManager.get_current_level_root():
		# It says "local position" in function name but the docs say it is global position
		# and this agrees with empirical results
		var pos: Vector2 = state.get_contact_local_position(0)
		current_collision = CollisionResult.new()
		
		current_collision.game_time_seconds = SceneManager.get_current_level_root().game_timer.time_seconds
		current_collision.global_position = pos
		current_collision.collider = state.get_contact_collider_object(0) as Node2D

		last_collision = current_collision
	else:
		current_collision = null

func get_destructible_component() -> CollisionPolygon2D:
	return destructible_component

func on_body_entered(body: PhysicsBody2D):
	explode(body)

## Hook function for derived classes to take additional actions when having an interaction between the destructible component and another node
func _on_destructible_component_interaction(in_destructible_component: CollisionPolygon2D, destructible_node:Node) -> void:
	pass

## Runs damage logic and explodes if an interaction occurs
func explode(collided_body: PhysicsBody2D = null, force:bool = false):
	# Need to do a sweep to see all the things we have influenced
	# Need to be sure not to "double-damage" things both from influence and from direct hit 
	# The body here is the direct hit body that will trigger the projectile to explode if an interaction happens
	if not run_collision_logic:
		return
	if calculated_hit:
		return
	
	var had_interaction:bool = false if not force else true
	if is_instance_valid(collided_body) and collided_body.get_collision_layer_value(10): # ProjectileBlocker (shield, etc) hack
		# FIXME if not inside_of_players_shield...:
		had_interaction = true
	var affected_nodes: Array[Node2D] = _find_interaction_overlaps()
	
	#region Node Group Determination

	var processed_nodes_set: Dictionary[Node, bool] = {}
	var damaged_processed_map: Dictionary[Node, float] = {}
	var destructed_processed_map: Dictionary[Node, Vector2] = {}

	for node in affected_nodes:
		# See if this node is a "Damageable" or a "Destructable"
		# Damageable:
		var root_node: Node = Groups.get_parent_in_group(node, Groups.Damageable)
		if root_node:
			var damage_amount = _calculate_damage(node)
			if damage_amount > 0:
				had_interaction = true
				damaged_processed_map[root_node] = maxf(damage_amount, damaged_processed_map.get(root_node, 0.0))
				processed_nodes_set[root_node] = true
				
		# Destructible:
		# -Some projectiles don't have a destructible node and don't damage the terrain or other shatterable things.
		if destructible_component:
			root_node = Groups.get_parent_in_group(node, Groups.Destructible)
			if root_node and root_node not in destructed_processed_map:
				_on_destructible_component_interaction(destructible_component, root_node)
				var contact_point: Vector2 = center_destructible_on_impact_point(destructible_component)

				had_interaction = true
				destructed_processed_map[root_node] = contact_point
				processed_nodes_set[root_node] = true
	#endregion

	#region Events and Damage Dispatch

	# Process events for destructible components and combine for those that are the same
	# Process damage at end as took max damage if there were multiple colliders on single damageable root node
	# Also process destructible components at end as some may also be damageable and want to emit a single global event

	var instigator := get_instigator()

	for node in processed_nodes_set:
		# Default damage to 0 if this is only a destructible node and not also damageable
		var damage_amount:float = damaged_processed_map.get(node, 0.0)
		# Default to global_position for contact point if this is just a damageable node
		var contact_point:Vector2 = destructed_processed_map.get(node, global_position)

		if node.is_in_group(Groups.Destructible):
			damage_destructible_node(node, instigator, self, contact_point, destructible_scale_multiplier)
			#node.damage(self, contact_point, destructible_scale_multiplier)
		if node.is_in_group(Groups.Damageable):
			damage_damageable_node(node, instigator, self, damage_amount)
			#node.take_damage(instigator, self, damage_amount)

		GameEvents.took_damage.emit(node, instigator, self, contact_point, damage_amount)
	
	#endregion

	# Explode
	if had_interaction and should_explode_on_impact: 
		destroy()
	
## For use with a Damageable group nodes only.
## This method exists to be overridden by classes extending [WeaponProjectile], as a hook.
func damage_damageable_node(
	damageable:Node, instigator:Node, projectile:WeaponProjectile,
	damage_amount:float
	) -> void:
	
	damageable.take_damage(instigator, projectile, damage_amount)
	
## For use with a Destructible group nodes only.
## This method exists to be overridden by classes extending [WeaponProjectile], as a hook.
@warning_ignore("unused_parameter")
func damage_destructible_node(
	destructible:Node, instigator:Node, projectile:WeaponProjectile,
	contact_point:Vector2, destructible_scale_multiplier:Vector2
	) -> void:
	
	var container = WeaponProjectilePhysicsContainer.new(self)
	destructible.damage(container, contact_point, destructible_scale_multiplier)

func get_instigator() -> Node2D:
	return owner_tank.get_parent() as Node2D if is_instance_valid(owner_tank) else null
	
func center_destructible_on_impact_point(destructible: CollisionPolygon2D) -> Vector2:
	var destructible_polygon: PackedVector2Array = destructible.polygon
	# Get velocity vector direction to determine translation direction
	var movement_dir : Vector2 = last_recorded_linear_velocity.normalized()
	var circle : Circle = Circle.create_from_points(destructible_polygon)
	
	var contact_point: Vector2 = _determine_contact_point(movement_dir, circle.radius)
	
	var translation_radius: float = circle.radius * destructible_scale_multiplier.length()
	var translation: Vector2 = contact_point - global_position + translation_radius * movement_dir
	
	for i in range(destructible_polygon.size()):
		destructible_polygon[i] += translation
	
	return contact_point

## Explodes if supported and then ensures that the projectile is destroyed
func explode_and_force_destroy(body:PhysicsBody2D = null, force:bool = false):
	explode(body, force)
	destroy()
	
func destroy():
	if destroyed:
		#print_debug("WeaponProjectile(%s): Already destroyed" % name)
		return
		
	destroyed = true
	#print_debug("WeaponProjectile(%s): Destroying" % name)

	if explosion_to_spawn:
		spawn_explosion(explosion_to_spawn)
	
	_apply_post_processing()
	
	if not kill_after_turns_elapsed:
		completed_lifespan.emit(self)
	
	queue_free()
	
func destroy_after_lifetime(lifetime:float = max_lifetime) -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(destroy)
	timer.start(lifetime)
	
func spawn_explosion(scene:PackedScene) -> void:
	var instance:Explosion
	if scene.can_instantiate():
		instance = scene.instantiate()
		instance.global_position = global_position
		if rescale_explosion != Vector2.ONE:
			instance.apply_scale(rescale_explosion)
		# Per - weapon_projectile.gd:191 @ spawn_explosion(): Parent node is busy setting up children, `add_child()` failed. Consider using `add_child.call_deferred(child)` instead.
		if not firing_container: firing_container = _get_container()
		firing_container.add_child.call_deferred(instance)

func _physics_process(_delta: float) -> void:
	# Need to record this for contact point determination on impact as the linear_velocity there is after the collision
	last_recorded_linear_velocity = linear_velocity
	# print_debug("LinearVelocity=%s" % [linear_velocity])
	
func _determine_contact_point(movement_dir: Vector2, radius: float) -> Vector2:
	var space_state = get_world_2d().direct_space_state

	var extent: Vector2 = movement_dir * radius * 4.0

	var query_params := PhysicsRayQueryParameters2D.create(
		global_position - extent, global_position + extent,
		 Collisions.CompositeMasks.damageable)
		
	query_params.exclude = [self]
	
	var result: Dictionary = space_state.intersect_ray(query_params)
	if !result:
		push_warning("WeaponProjectile(%s): No contact point found for projectile - returning default position=%s" % [name, global_position])
		return global_position
	return result["position"]

func _get_collision_transform() -> Transform2D:
	return Transform2D(0, global_position)

func _find_interaction_overlaps() -> Array[Node2D]:
	var space_state = get_world_2d().direct_space_state
	
	# TODO: Maybe this belongs in Collisions auto-load
	var params = PhysicsShapeQueryParameters2D.new()
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = Collisions.CompositeMasks.damageable
	params.margin = Collisions.default_collision_margin
	params.transform = _get_collision_transform()
	params.exclude = [self]
	
	# More optimized shape creation for interfacing with the physics server
	# Given a handle (rid) that needs to be freed when done
	var shape_rid = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(shape_rid, max_falloff_distance)
	params.shape_rid = shape_rid
	
	# Note that each contact point is reported so for a large radius you may end up selecting the same collider multiple times
	# Unfortunately no way to remove contact point info so we need to increase the max results (esp. for the mega nuke) and then 
	# only append the unique colliders
	var results: Array[Dictionary] = space_state.intersect_shape(params, Collisions.weapon_sweep_result_count)

	var collision_results: Array[Node2D] = []

	#print("WeaponProjectile(" + name + "): Found " + str(results.size()) + " overlaps with projectile")
	for result:Dictionary in results:
		var collider = result["collider"] as Node2D
		if(!is_instance_valid(collider)):
			push_warning("WeaponProjectile(" + name + " damage overlapped with non-Node2D" +  result["collider"].name)
			continue
		if not collider in collision_results:
			if OS.is_debug_build():
				print("WeaponProjectile(" + name + " damage overlapped with " + collider.name)
			collision_results.append(collider)

	# Release the shape when done with physics queries.
	PhysicsServer2D.free_rid(shape_rid)
	
	return collision_results

func _calculate_damage(target: Node2D) -> float:
	return _calculate_point_damage(_get_node_impact_position(target))

func _get_impact_point() -> Vector2:
	if _is_last_collision_relevant():
		return last_collision.global_position
	return global_position

func _get_node_impact_position(node: Node2D) -> Vector2:
	if _is_last_collision_relevant() and last_collision.collider == node:
		return last_collision.global_position
	return node.global_position

func _is_last_collision_relevant() -> bool:
	return is_instance_valid(last_collision)
	#return last_collision and \
	#	 SceneManager.get_current_level_root().game_timer.time_seconds - last_collision.game_time_seconds <= last_collider_time_tolerance

func _calculate_point_damage(pos: Vector2) -> float:
	var impact_point:Vector2 = _get_impact_point()

	var dist = (pos - impact_point).length()
	if dist >= max_falloff_distance:
		return 0.0
	if dist <= min_falloff_distance:
		return max_damage
	
	match damage_falloff_type:
		DamageFalloffType.Constant:
			return max_damage
		DamageFalloffType.Linear:
			return _calculate_dist_frac(dist) * max_damage
		DamageFalloffType.InverseSquare:
			var falloff = _calculate_dist_frac(dist)
			return falloff * falloff * max_damage
		_:
			push_error("Unrecognized damage type: " + str(damage_falloff_type))
			return max_damage
			
func _calculate_dist_frac(dist: float):
	return  (1.0 - (dist - min_falloff_distance) / (max_falloff_distance - min_falloff_distance))
	
func _get_container() -> Node:
	var container = SceneManager.get_current_level_root()
	if container == null: container = SceneManager.current_scene
	#deployed_container = SceneManager.current_scene
	if container.has_method("get_container"):
		container = container.get_container()
	return container

func _emit_completed_lifespan_without_destroying(time:float) -> void:
	if time > 0.0: await get_tree().create_timer(time).timeout
	completed_lifespan.emit(self)
	
func _on_turn_started(_controller: TankController) -> void:
	if kill_after_turns_elapsed_count_only_self_turns:
		## Only count turn changes if owner tank is alive and their turn just ended.
		if owner_tank:
			if _controller != owner_tank.controller:
				return
	# Increment turn count
	_turns_since_spawned += 1
	if _turns_since_spawned >= kill_after_turns_elapsed:
		destroy()

func apply_all_mods(mods: Array[ModProjectile] = upgrades) -> void:
	for mod in mods:
		mod.modify_projectile(self)
		
func apply_new_mod(mod: ModProjectile) -> void:
	upgrades.append(mod)
	mod.modify_projectile(self)

func _apply_post_processing() -> void:
	if not post_processing_scene or not SceneManager._current_level_root_node:
		return
	#print_debug("%s - Adding post-processing scene=%s" % [name, post_processing_scene.resource_path])
	var effect_node: Node2D = post_processing_scene.instantiate() as Node2D
	if not effect_node:
		push_error("%s - Could not instantiate post-processing scene=%s" % [name, post_processing_scene.resource_path])
		return
	SceneManager.get_current_level_root().post_processing.apply_effect(effect_node)
