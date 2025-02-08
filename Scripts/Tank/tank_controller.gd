# Abstract base class for AI and player controllers
class_name TankController extends Node2D

func _ready() -> void:
	GameEvents.connect("turn_ended", _on_turn_ended)
	
func begin_turn() -> void:
	tank.reset_orientation()

var tank: Tank:
	get: return _get_tank()

func _get_tank() -> Tank:
	push_error("abstract function")
	return null
	
func _on_turn_ended(player: TankController) -> void:
	if(self != player): return
	
	tank.toggle_gravity(true)
