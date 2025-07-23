## Readies the parachute on the owner tank.
## Sets the parachute flag on the owner tank and then listens for start falling to mark activation
## Then on stop falling will remove the parachute flag and destroy itself by calling weapon.kill_projectile
class_name ParachuteEquip extends Node2D

var _owner_tank:Tank
var _weapon:Weapon
var _game_level:GameLevel

signal completed_lifespan(node: Node2D) ## Tracked by Weapon class

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
	tank.parachute_activated.connect(_on_parachute_activated)
	# Free memory if tank is killed
	tank.tank_killed.connect(queue_free.unbind(3))

func destroy() -> void:
	if is_instance_valid(_owner_tank):
		_owner_tank.has_parachute = false
	queue_free()

func _on_parachute_activated(tank: Tank) -> void:
	print_debug("%s-%s: Started falling with parachute" % [name, tank.name])
	tank.tank_stopped_falling.connect(_on_tank_stopped_falling)

func _on_tank_stopped_falling(tank: Tank) -> void:
	print_debug("%s-%s: Stopped falling with parachute" % [name, tank.name])
	_deactivate_parachute()

func _deactivate_parachute() -> void:
	print_debug("%s-%s: Parachute item consumed" % [name, _owner_tank.name if is_instance_valid(_owner_tank) else &"NULL"])
	destroy()
