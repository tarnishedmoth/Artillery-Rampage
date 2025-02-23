class_name WeaponProjectile extends RigidBody2D

#TODO: We might not need the Overlap if we only have the weapon projectile interact with Area2D's and not other physics bodies

enum DamageFalloffType
{
	Constant,
	Linear,
	InverseSquare
}

# The idea here is that we are using RigidBody2D for the physics behavior
# and the Area2D as the overlap detection for detecting hits
@export var power_velocity_mult:float = 1
@export var color: Color = Color.BLACK

@export_category("Damage")
@export var damage_falloff_type: DamageFalloffType = DamageFalloffType.Linear

@export_category("Damage")
@export var min_falloff_distance: float = 10

@export_category("Damage")
@export var max_falloff_distance: float = 60

@export_category("Damage")
@export var min_damage: float = 10

@export_category("Damage")
@export var max_damage: float = 100

@export_category("Destructible")
@export var destructible_scale_multiplier:Vector2 = Vector2(10 , 10)

@onready var overlap = $Overlap

var calculated_hit: bool
var owner_tank: Tank;

func set_spawn_parameters(in_owner_tank: Tank, power:float, angle:float):
	self.owner_tank = in_owner_tank
	linear_velocity = Vector2.from_angle(angle) * power * power_velocity_mult
	
func _ready() -> void:
	modulate = color
	
	overlap.connect("body_entered", on_body_entered)
	GameEvents.emit_weapon_fired(self)
	
func on_body_entered(_body: Node2D):
	# Need to do a sweep to see all the things we have influenced
	# Need to be sure not to "double-damage" things both from influence and from direct hit
	# The body here is the direct hit body that will trigger the projectile to explode if an interaction happens
	if calculated_hit:
		return
	var affected_nodes = _find_interaction_overlaps()
	var had_interaction:bool = false
	
	var processed_set: Dictionary = {}
	
	for node in affected_nodes:
		# See if this node is a "Damageable" or a "Destructable"
		var root_node = get_parent_in_group(node, Groups.Damageable)
		if root_node:
			if root_node in processed_set:
				continue
			var damage_amount = _calculate_damage(node)
			if damage_amount > 0:
				root_node.take_damage(owner_tank, self, damage_amount)
				had_interaction = true
		root_node = get_parent_in_group(node, Groups.Destructible)
		if root_node:
			if root_node in processed_set:
				continue
			root_node.damage($Destructible, destructible_scale_multiplier)
			had_interaction = true
		processed_set[root_node] = root_node
	# end for
	
	calculated_hit = true

	if had_interaction:
		destroy()
		

func get_parent_in_group(node: Node, group: String) -> Node:
	if node.is_in_group(group):
		return node
	if node.get_parent() == null:
		return null
	return get_parent_in_group(node.get_parent(), group)

func destroy():
	GameEvents.emit_turn_ended(owner_tank.owner)
	queue_free()
	
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
	
	var results: Array[Dictionary] = space_state.intersect_shape(params)

	var collision_results: Array[Node2D] = []

	print("WeaponProjectile(" + name + "): Found " + str(results.size()) + " overlaps with projectile")
	for result:Dictionary in results:
		var collider = result["collider"] as Node2D
		if(!is_instance_valid(collider)):
			push_warning("WeaponProjectile(" + name + " damage overlapped with non-Node2D" +  result["collider"].name)
			continue
		print("WeaponProjectile(" + name + " damage overlapped with " + collider.name)
		collision_results.append(collider)

	# Release the shape when done with physics queries.
	PhysicsServer2D.free_rid(shape_rid)
	
	return collision_results

func _calculate_damage(target: Node2D) -> float:
	return _calculate_point_damage(target.global_position)

func _calculate_point_damage(pos: Vector2) -> float:
	var dist = (pos - global_position).length()
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
