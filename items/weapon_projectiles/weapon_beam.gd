class_name WeaponBeam extends WeaponProjectile

var speed = 8

@onready var laser_end = $LaserEnd

func modulate_enabled() -> bool:
	return false

@warning_ignore("unused_parameter")
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
		explode()

## Override to return laser transform
func _get_collision_transform() -> Transform2D:
	return Transform2D(0, laser_end.global_position)

## Override to change the destructible position to laser end position
func _on_destructible_component_interaction(in_destructible_component: CollisionPolygon2D, destructible_node:Node) -> void:
	super._on_destructible_component_interaction(in_destructible_component, destructible_node)
	in_destructible_component.position = laser_end.position
