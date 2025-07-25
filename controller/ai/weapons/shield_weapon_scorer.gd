extends WeaponScorer

@export var shield_weapon_scene:PackedScene

## Max distance fraction in terms of window width
@export_range(0.0, 1.0, 0.01) var max_target_distance_fraction:float = 0.125

var _max_target_distance:float

func _ready() -> void:
	if not shield_weapon_scene:
		push_error("Missing shield weapon scene")
		return
	var viewport_size:Vector2 = get_viewport().get_visible_rect().size
	_max_target_distance = viewport_size.x * max_target_distance_fraction
	
func handles_weapon(weapon: Weapon, _projectile: Node2D) -> bool:
	return shield_weapon_scene and weapon.scene_file_path == shield_weapon_scene.resource_path

func compute_score(_tank: Tank, _weapon: Weapon, _in_projectile: Node2D, target_distance:float) -> float:
	# Activate shield if target is close
	# TODO: Don't activate the shield again if it is already active
	# Need to determine how to detect if the shield is already active
	return 1e100 if target_distance <= _max_target_distance else 0.0
