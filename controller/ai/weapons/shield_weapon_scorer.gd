extends WeaponScorer

@export var shield_weapon_scene:PackedScene

## Max distance fraction in terms of window width
@export_range(0.0, 1.0, 0.01) var max_target_distance_fraction:float = 0.125

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

func compute_score(tank: Tank, _weapon: Weapon, _in_projectile: Node2D, target_distance:float) -> float:
	if _is_shield_already_active():
		return 0.0
	
	# Activate shield if target is close
	# Need to determine how to detect if the shield is already active
	_owner_tank = tank
	return 1e100 if target_distance <= _max_target_distance else 0.0

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
