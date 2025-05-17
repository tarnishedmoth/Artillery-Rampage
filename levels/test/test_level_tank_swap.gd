extends Node2D

const tank_scene:PackedScene = preload("res://tank/tank.tscn")

@onready var enemy1:TankController = $GameLevel/Enemy1
@onready var enemy2:TankController = $GameLevel/Enemy2

func _ready() -> void:
	# Contrived example to test
	_replace_tank(enemy1)
	_replace_tank(enemy2)
	
func _replace_tank(enemy:TankController):
	var new_tank := tank_scene.instantiate() as Tank
	# Super health
	new_tank.max_health = 10000
	enemy.replace_tank(new_tank)
