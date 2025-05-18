class_name WeaponBeam extends WeaponProjectile

var speed = 8

@onready var laser_end = $LaserEnd

func modulate_enabled() -> bool:
	return false

func _calculate_damage(target: Node2D) -> float:
	return 100

func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	# treat laser as a ray, not a projectile
	#$PhysicsShape.position.x += speed
	#$PhysicsShape.scale.x += 2 * speed
	#$Destructible.position.x += speed
	#$Destructible.scale.x += 2 * speed
	$BeamSprite.position.x += speed / 2
	$BeamSprite.scale.y += speed
	
	laser_end.position.x += speed
	see_if_beam_collides_with_anything()

func see_if_beam_collides_with_anything():
	var space_state = get_world_2d().direct_space_state
	var query_params := PhysicsRayQueryParameters2D.create(
		global_position, laser_end.global_position,
		 Collisions.CompositeMasks.damageable)
	query_params.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query_params)
	if result.size() > 0:
		beam_explode()

## Runs damage logic and explodes if an interaction occurs
func beam_explode():
	# Need to do a sweep to see all the things we have influenced
	# Need to be sure not to "double-damage" things both from influence and from direct hit
	# The body here is the direct hit body that will trigger the projectile to explode if an interaction happens
	if not run_collision_logic:
		return
	if calculated_hit:
		return
	
	var had_interaction:bool = false
	#if is_instance_valid(collided_body) and collided_body.get_collision_layer_value(10): # ProjectileBlocker (shield, etc) hack
		## FIXME if not inside_of_players_shield...:
		#had_interaction = true
	var affected_nodes = _find_interaction_overlaps()
	
	var damaged_processed_map: Dictionary[Node, float] = {}
	var destructed_processed_set: Dictionary[Node, Node] = {}

	for node in affected_nodes:
		## See if this node is a "Damageable" or a "Destructable"
		## Damageable:
		var root_node: Node = Groups.get_parent_in_group(node, Groups.Damageable)
		if root_node:
			var damage_amount = _calculate_damage(node)
			if damage_amount > 0:
				had_interaction = true
				damaged_processed_map[root_node] = maxf(damage_amount, damaged_processed_map.get(root_node, 0.0))
				
		## Destructible:
		# -Some projectiles don't have a destructible node and don't damage the terrain or other shatterable things.
		if destructible_component:
			root_node = Groups.get_parent_in_group(node, Groups.Destructible)
			if root_node and root_node not in destructed_processed_set:
				# Part that's different from other weapon_projectiles
				destructible_component.position = laser_end.position
				var contact_point: Vector2 = center_destructible_on_impact_point(destructible_component)
				
				# Pass 0 for damage as destructible components don't take health-based damage
				GameEvents.took_damage.emit(root_node, get_instigator(), self, contact_point, 0.0)
				root_node.damage(self, contact_point, destructible_scale_multiplier)

				had_interaction = true
				destructed_processed_set[root_node] = root_node
	## end for

	# Process damage at end as took max damage if there were multiple colliders on single damageable root node
	for damageable_node in damaged_processed_map:
		var damage: float = damaged_processed_map[damageable_node]
		damage_damageable_node(damageable_node, damage) # I want to hook here without overriding this function

	# Explode
	if had_interaction and should_explode_on_impact: destroy()

func _find_interaction_overlaps() -> Array[Node2D]:
	var space_state = get_world_2d().direct_space_state
	
	# TODO: Maybe this belongs in Collisions auto-load
	var params = PhysicsShapeQueryParameters2D.new()
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = Collisions.CompositeMasks.damageable
	params.margin = Collisions.default_collision_margin
	# Part that's different from other weapon_projectiles
	params.transform = Transform2D(0, laser_end.global_position)
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
