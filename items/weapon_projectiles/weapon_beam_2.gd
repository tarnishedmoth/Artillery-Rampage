class_name WeaponBeam2 extends WeaponProjectile

var speed = 8

@onready var laser_end = $LaserEnd

var can_travel = true
var time_since_last_hit = 0
var time_to_wait_between_hits = 0.75

func modulate_enabled() -> bool:
	return false

func _calculate_damage(target: Node2D) -> float:
	return 50

func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	if can_travel:
		$BeamSprite.position.x += speed / 2
		$BeamSprite.scale.y += speed
		laser_end.position.x += speed
		see_if_beam_collides_with_anything()
	else:
		time_since_last_hit += _delta
		if time_since_last_hit >= time_to_wait_between_hits:
			can_travel = true

func see_if_beam_collides_with_anything():
	var space_state = get_world_2d().direct_space_state
	var query_params := PhysicsRayQueryParameters2D.create(
		global_position, laser_end.global_position,
		 Collisions.CompositeMasks.damageable)
	query_params.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query_params)
	if result.size() > 0:
		explode()
		can_travel = false
		time_since_last_hit = 0

## Override to return laser transform
func _get_collision_transform() -> Transform2D:
	return Transform2D(0, laser_end.global_position)

## Override to change the destructible position to laser end position
func _on_destructible_component_interaction(in_destructible_component: CollisionPolygon2D, destructible_node:Node) -> void:
	super._on_destructible_component_interaction(in_destructible_component, destructible_node)
	in_destructible_component.position = laser_end.position
