extends WeaponScorer

@export var shield_weapon_scene:PackedScene

## Max distance fraction in terms of window width
@export_range(0.0, 1.0, 0.001) var max_target_distance_fraction:float = 0.125

var _max_target_distance:float
var _owner_tank:Tank
var _active_shields:Array[WeaponProjectile]

func _ready() -> void:
	if not shield_weapon_scene:
		push_error("Missing shield weapon scene")
		return

	var viewport_size:Vector2 = get_viewport().get_visible_rect().size
	_max_target_distance = viewport_size.x * max_target_distance_fraction
	
	GameEvents.projectile_fired.connect(_on_projectile_fired)

func handles_weapon(weapon: Weapon, _projectile: Node2D) -> bool:
	return shield_weapon_scene and weapon.scene_file_path == shield_weapon_scene.resource_path

func compute_score(tank: Tank, _weapon: Weapon, _in_projectile: Node2D, _target_distance:float, opponents: Array[TankController], comparison_result:int) -> float:
	if _is_shield_already_active():
		return 0.0
	
	# Activate shield if more than one enemy is close
	# TODO: Revise this strategy
	_owner_tank = tank

	var use_shield:bool = _multiple_enemies_are_close(tank, opponents)
	if not use_shield:
		return 0.0

	# Big number so that it is picked when selecting the best weapon and then small number so picked when selecting the "worst weapon"
	return 1e100 if comparison_result > 0 else 0.01

func _multiple_enemies_are_close(tank: Tank, opponents: Array[TankController]) -> bool:
	var tank_pos:Vector2 = tank.global_position
	var matching_count:int = 0
	var max_target_dist_sq:float = _max_target_distance * _max_target_distance

	for enemy in opponents:
		if enemy.global_position.distance_squared_to(tank_pos) <= max_target_dist_sq:
			matching_count += 1
			if matching_count > 1:
				return true
	
	return false

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	var source_weapon:Weapon = projectile.source_weapon
	if not source_weapon:
		return
	if not handles_weapon(source_weapon, projectile):
		return

	# Only keep track of our shot projectiles
	var source_tank:Tank = source_weapon.parent_tank
	if not source_tank or source_tank != _owner_tank:
		return

	print_debug("%s(%s): Shield projectile fired: %s" % [name, _owner_tank.name, projectile.name])
	projectile.completed_lifespan.connect(_on_shield_deactivated)

	_active_shields.push_back(projectile)

func _on_shield_deactivated(projectile:WeaponProjectile) -> void:
	print_debug("%s(%s): Shield deactivated: %s" % [name, _owner_tank.name, projectile.name])
	_active_shields.erase(projectile)

func _is_shield_already_active() -> bool:
	return not _active_shields.is_empty()
