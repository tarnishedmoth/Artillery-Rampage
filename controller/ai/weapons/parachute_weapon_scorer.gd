extends WeaponScorer

@export var parachute_weapon_scene:PackedScene

## Min distance fraction in terms of window width
@export_range(0.0, 1.0, 0.01) var min_target_distance_fraction:float = 0.5

## Min distance fraction in terms of window height
@export_range(0.0, 1.0, 0.01) var min_height_fraction:float = 0.5

var _min_target_distance:float
var _min_height:float

func _ready() -> void:
	if not parachute_weapon_scene:
		push_error("Missing parachute weapon scene")
		return
	var viewport_size:Vector2 = get_viewport().get_visible_rect().size
	_min_target_distance = viewport_size.x * min_target_distance_fraction
	_min_height = viewport_size.y * min_height_fraction
	
func handles_weapon(weapon: Weapon, _projectile: Node2D) -> bool:
	return parachute_weapon_scene and weapon.scene_file_path == parachute_weapon_scene.resource_path

func compute_score(tank: Tank, _weapon: Weapon, _in_projectile: Node2D, target_distance:float) -> float:
	# Simple implementation that will activate the parachute if criteria met
	if tank.has_parachute or target_distance < _min_target_distance or tank.global_position.y >_min_height:
		return 0
	# Big number so that it is picked when selecting the best weapon
	return 1e100
