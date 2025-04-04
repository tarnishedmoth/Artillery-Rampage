extends Node2D

@onready var player:Player = $GameLevel/Player

@export_range(0.0, 1.0, 0.01) var player_health_pct = 0.5

func _ready() -> void:
	player.tank.take_damage(player, self, player.tank.max_health * ( 1.0 - player_health_pct))
