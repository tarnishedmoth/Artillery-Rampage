extends Node2D

# Use a derived tank scene that has different capabilities
const tank_scene:PackedScene = preload("res://tank/heavy_tank.tscn")

@onready var enemy1:TankController = $GameLevel/Enemy1
@onready var enemy2:TankController = $GameLevel/Enemy2
@onready var player:TankController = $GameLevel/Player

func _ready() -> void:
	# Contrived example to test
	_replace_tank(player)
	_replace_tank(enemy1)
	_replace_tank(enemy2)
	
func _replace_tank(controller:TankController):
	var new_tank := tank_scene.instantiate() as Tank
	controller.replace_tank(new_tank)
