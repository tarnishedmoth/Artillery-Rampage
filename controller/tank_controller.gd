# Abstract base class for AI and player controllers
class_name TankController extends Node2D

@export var enable_damage_before_first_turn:bool = true 
var _initial_fall_damage:bool

func _ready() -> void:
	GameEvents.connect("turn_ended", _on_turn_ended)
	GameEvents.connect("turn_started", _on_turn_started)
	
	_initial_fall_damage = tank.enable_fall_damage
	
	if !enable_damage_before_first_turn:
		print("TankController(%s) - _ready: Disable fall damage before first turn" % [name])
		tank.enable_fall_damage = false
	
func begin_turn() -> void:
	#tank.reset_orientation()
	tank.enable_fall_damage = _initial_fall_damage
	
var tank: Tank:
	get: return _get_tank()

func _get_tank() -> Tank:
	push_error("abstract function")
	return null

func set_color(value: Color) -> void:
	tank.color = value

func _on_turn_ended(_player: TankController) -> void:
	# On any player turn ended, simulate physics	
	tank.toggle_gravity(true)

func _on_turn_started(_player: TankController) -> void:
	# Ony any player turn started, stop simulating physics
	tank.reset_orientation()
