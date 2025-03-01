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
		print("Wind(%s): set to %s" % [name, str(value)])
		GameEvents.emit_wind_updated(self)
	get:
		return wind
		
var _active_projectile: WeaponProjectile

func _ready() -> void:
	wind = Vector2(_randomize_wind(), 0.0)
	GameEvents.connect("projectile_fired", _on_projectile_fired)

func _randomize_wind() -> int:
	# Increase "no-wind" probability by allowing negative and then clamping to zero if the random number is < 0
	return max(randi_range(wind_min, wind_max), 0) * (1 if randf() <= 0.5 + wind_sign_bias * 0.5 else -1)

func _physics_process(delta: float) -> void:
	if !is_instance_valid(_active_projectile):
		return
	_apply_wind_to_active_weapon(delta)

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	print("Wind(%s): on_projectile_fired: %s" % [name, projectile.name])
	_active_projectile = projectile
	
func _apply_wind_to_active_weapon(delta: float) -> void:
	_active_projectile.apply_central_force(wind * wind_scale * delta)
