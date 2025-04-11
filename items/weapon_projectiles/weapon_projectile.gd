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

signal completed_lifespan ## Tracked by Weapon class


# The idea here is that we are using RigidBody2D for the physics behavior
# and the Area2D as the overlap detection for detecting hits

@export var color: Color = Color.BLACK

## Self destroys once this time has passed.[br]
## When [member kill_after_turns_elapsed] is used, this time emits [signal completed_lifespan].
@export var max_lifetime: float = 10.0
@export_range(0,99) var kill_after_turns_elapsed:int = 0 ## If >0, destroys after turns passed.
@export var explosion_to_spawn:PackedScene

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

## Indicate whether need to explode on impact with supported collision layers and cause damage
## This replaces the "Overlap" concept
@export var should_explode_on_impact:bool = true ## Deployable weapons should have this set to False.

var calculated_hit: bool
var owner_tank: Tank;
var source_weapon: Weapon # The weapon we came from
var firing_container
var destructible_component:CollisionPolygon2D

var _turns_since_spawned:int = 0

# TODO: We can probably combine this with above should_explode_on_impact
# Removed the Overlap concept as can handle the overlap interaction through the rigid body
# This also allows us to use continuous collision detection to fix the tunneling problem we see with projectiles going through the terrain
var can_explode:bool = true # used by MIRV

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
	#if should_explode_on_impact: connect("body_entered", on_body_entered)
	connect("body_entered", on_body_entered)
	if has_node('Destructible'):
		destructible_component = get_node('Destructible')
		
	if kill_after_turns_elapsed > 0:
		GameEvents.turn_ended.connect(_on_turn_ended)
		_emit_completed_lifespan_without_destroying(max_lifetime) # Relinquish turn control
	elif max_lifetime > 0.0: destroy_after_lifetime()
	
	modulate = color
	apply_all_mods() # This may not be desired but it probably is. If the weapon's stats are retained across matches, this could double the effect unintentionally
		
	GameEvents.emit_projectile_fired(self)
	
func set_sources(tank:Tank,weapon:Weapon) -> void:
	owner_tank = tank
	source_weapon = weapon
	if explosion_to_spawn:
		firing_container = _get_container()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Store any collision results for later access
	if state.get_contact_count() >= 1:
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

func on_body_entered(_body: PhysicsBody2D):
	# Need to do a sweep to see all the things we have influenced
	# Need to be sure not to "double-damage" things both from influence and from direct hit
	# The body here is the direct hit body that will trigger the projectile to explode if an interaction happens
	if not can_explode:
		return
	if calculated_hit:
		return
	
	var had_interaction:bool = false
	if _body.get_collision_layer_value(10): # ProjectileBlocker (shield, etc) hack
		# FIXME if not inside_of_players_shield...:
		had_interaction = true
	var affected_nodes = _find_interaction_overlaps()
	
	var damaged_processed_map: Dictionary[Node, float] = {}
	var destructed_processed_set: Dictionary[Node, Node] = {}

	for node in affected_nodes:
		# See if this node is a "Damageable" or a "Destructable"
		var root_node: Node = Groups.get_parent_in_group(node, Groups.Damageable)
		if root_node:
			var damage_amount = _calculate_damage(node)
			if damage_amount > 0:
				had_interaction = true
				damaged_processed_map[root_node] = maxf(damage_amount, damaged_processed_map.get(root_node, 0.0))
		# Some projectiles don't have a destructible node, e.g. MIRV
		if destructible_component:
			root_node = Groups.get_parent_in_group(node, Groups.Destructible)
			if root_node and root_node not in destructed_processed_set:
				var contact_point: Vector2 = center_destructible_on_impact_point(destructible_component)
				root_node.damage(self, contact_point, destructible_scale_multiplier)
				had_interaction = true
				destructed_processed_set[root_node] = root_node
	# end for

	# Process damage at end as took max damage if there were multiple collidors on single damageable root node
	for damageable_node in damaged_processed_map:
		var damage: float = damaged_processed_map[damageable_node]
		damage_damageable_node(damageable_node, damage) # I want to hook here without overriding this function

	
	# FIXME: Technically shouldn't do this and should set to true and also always call destroy but MIRV doesn't work correctly without it
	calculated_hit = not affected_nodes.is_empty()

	# Always explode on impact
	if had_interaction and should_explode_on_impact:
		destroy()
		
func damage_damageable_node(damageable_node: Node, damage:float) -> void:
	damageable_node.take_damage(owner_tank, self, damage)
		
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

func destroy():
	if explosion_to_spawn:
		spawn_explosion(explosion_to_spawn)
	
	_apply_post_processing()
	
	completed_lifespan.emit()
	queue_free()
	
func destroy_after_lifetime(lifetime:float = max_lifetime) -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(destroy)
	timer.start(lifetime)
	
func spawn_explosion(scene:PackedScene) -> void:
	var instance
	if scene.can_instantiate():
		instance = scene.instantiate()
		instance.global_position = global_position
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

func _find_interaction_overlaps() -> Array[Node2D]:
	var space_state = get_world_2d().direct_space_state
	
	# TODO: Maybe this belongs in Collisions auto-load
	var params = PhysicsShapeQueryParameters2D.new()
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = Collisions.CompositeMasks.damageable
	params.margin = Collisions.default_collision_margin
	params.transform = Transform2D(0, global_position)
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

	print("WeaponProjectile(" + name + "): Found " + str(results.size()) + " overlaps with projectile")
	for result:Dictionary in results:
		var collider = result["collider"] as Node2D
		if(!is_instance_valid(collider)):
			push_warning("WeaponProjectile(" + name + " damage overlapped with non-Node2D" +  result["collider"].name)
			continue
		if not collider in collision_results:
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
	var container = SceneManager.get_current_level_root() if not null else SceneManager.current_scene
	#deployed_container = SceneManager.current_scene
	if container.has_method("get_container"):
		container = container.get_container()
	return container

func _emit_completed_lifespan_without_destroying(time:float) -> void:
	if time > 0.0: await get_tree().create_timer(time).timeout
	completed_lifespan.emit()
	
func _on_turn_ended() -> void:
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
	print_debug("%s - Adding post-processing scene=%s" % [name, post_processing_scene.resource_path])
	var effect_node: Node2D = post_processing_scene.instantiate() as Node2D
	if not effect_node:
		push_error("%s - Could not instantiate post-processing scene=%s" % [name, post_processing_scene.resource_path])
		return
	SceneManager.get_current_level_root().post_processing.apply_effect(effect_node)
