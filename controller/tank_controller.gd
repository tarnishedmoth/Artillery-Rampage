# Abstract base class for AI and player controllers
class_name TankController extends Node2D

func _ready() -> void:
	GameEvents.connect("turn_ended", _on_turn_ended)
	GameEvents.connect("turn_started", _on_turn_started)
	
func begin_turn() -> void:
	#tank.reset_orientation()
	pass

var tank: Tank:
	get: return _get_tank()

func _get_tank() -> Tank:
	push_error("abstract function")
	return null

func _on_turn_ended(_player: TankController) -> void:
	# On any player turn ended, simulate physics	
	tank.toggle_gravity(true)

func _on_turn_started(_player: TankController) -> void:
	# Ony any player turn started, stop simulating physics
	tank.reset_orientation()
