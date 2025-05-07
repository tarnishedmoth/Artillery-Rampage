class_name Wind extends Node

@export_category("Wind")
@export_range(0.0, 1e9, 0.001, "or_greater")
var wind_scale:float = 1.0

@export_category("Wind")
@export_range(-100, 1e9, 1, "or_greater")
var wind_min:int = -100

@export_category("Wind")
@export_range(0.0, 1e9, 1, "or_greater")
var wind_max:int = 100

@export_category("Wind")
@export_range(-1.0, 1.0, 0.01, "or_greater")
var wind_sign_bias:float = 0

var wind: Vector2 = Vector2():
	set(value):
		wind = value
		print_debug("Wind(%s): set to %s" % [name, str(value)])
		GameEvents.wind_updated.emit(self)
	get:
		return wind

var force: Vector2:
	get:
		return wind * wind_scale
				
var _active_projectile_set: Dictionary[WeaponProjectile, WeaponProjectile] = {}

func _ready() -> void:
	wind = Vector2(_randomize_wind(), 0.0)
	GameEvents.projectile_fired.connect(_on_projectile_fired)

func _randomize_wind() -> int:
	# Increase "no-wind" probability by allowing negative and then clamping to zero if the random number is < 0
	return max(randi_range(wind_min, wind_max), 0) * (1 if randf() <= 0.5 + wind_sign_bias * 0.5 else -1)

func _physics_process(delta: float) -> void:
	if _active_projectile_set.is_empty():
		return
	_apply_wind_to_active_projectiles(delta)

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	# Need to bind the extra projectile argument to connect
	projectile.completed_lifespan.connect(_on_projectile_destroyed.bind(projectile))
	_active_projectile_set[projectile] = projectile

	print_debug("Wind(%s): on_projectile_fired: %s - tracking=%d" % [name, projectile.name, _active_projectile_set.size()])

func _on_projectile_destroyed(projectile: WeaponProjectile) -> void:
	_active_projectile_set.erase(projectile)
	print_debug("Wind(%s): on_projectile_destroyed: %s - tracking=%d" % [name, projectile.name, _active_projectile_set.size()])
	
func _apply_wind_to_active_projectiles(delta: float) -> void:
	for projectile in _active_projectile_set:
		if is_instance_valid(projectile) and not projectile is WeaponBeam:
			projectile.apply_central_force(force * delta)
