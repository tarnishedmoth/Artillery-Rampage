## Readies the parachute on the owner tank.
## Sets the parachute flag on the owner tank and then listens for start falling to mark activation
## Then on stop falling will remove the parachute flag and destroy itself by calling weapon.kill_projectile
class_name ParachuteEquip extends Node2D

var _owner_tank:Tank
var _weapon:Weapon
var _fall_start_time:float = -1.0
var _game_level:GameLevel

signal completed_lifespan(node: Node2D) ## Tracked by Weapon class

@export_range(0.0, 1e9, 0.1, "or_greater")
var fall_time_usage_min_seconds:float = 0.25

@export_range(0.01, 3.0, 0.01)
var turn_completion_delay:float = 0.1

func _ready() -> void:
	await get_tree().create_timer(turn_completion_delay).timeout
	completed_lifespan.emit(self)
	
func set_sources(tank:Tank, weapon:Weapon) -> void:
	if SceneManager.is_precompiler_running: return
	
	_owner_tank = tank
	_weapon = weapon
	_game_level = SceneManager.get_current_level_root()
	
	tank.has_parachute = true
	tank.tank_started_falling.connect(_on_tank_started_falling)
	# Free memory if tank is killed
	tank.tank_killed.connect(queue_free.unbind(3))

func destroy() -> void:
	if is_instance_valid(_owner_tank):
		_owner_tank.has_parachute = false
	queue_free()

func _on_tank_started_falling(tank: Tank) -> void:
	print_debug("%s-%s: Started falling with parachute" % [name, tank.name])
	_fall_start_time = _get_time()
	
func _on_tank_stopped_falling(tank: Tank) -> void:
	var fall_dt:float = _get_time() - _fall_start_time
	print_debug("%s-%s: Stopped falling with parachute: fall_time=%.2fs" % [name, tank.name, fall_dt])
	if fall_dt >= fall_time_usage_min_seconds:
		_deactivate_parachute()

func _deactivate_parachute() -> void:
	print_debug("%s-%s: Parachute item consumed" % [name, _owner_tank.name if is_instance_valid(_owner_tank) else &"NULL"])
	destroy()

func _get_time() -> float:
	return _game_level.game_timer.time_seconds if _game_level else Time.get_ticks_msec() * 1000.0
