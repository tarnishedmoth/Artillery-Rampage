class_name StoryRoundSummary extends Control

@export var win_background:Texture
@export var lose_background:Texture

@onready var background:TextureRect = %Background
@onready var title:HUDElement = %Title
@onready var turns:HUDElement = %Turns
@onready var kills:HUDElement = %Kills
@onready var damage_done:HUDElement = %DamageDone
@onready var health_lost:HUDElement = %HealthLost

func _ready() -> void:
	var stats := RoundStatTracker.round_data
	if not stats:
		push_error("No stat tracking was recorded!")
		title.set_value("ERROR!")
		return
	title.set_label("%s:" % [stats.level_name])
	
	if stats.won:
		title.set_value("Victory!")
		background.texture = win_background
	else:
		title.set_value("Defeat :(")
		background.texture = lose_background
		
	turns.set_value(stats.turns)
	kills.set_value(stats.kills)
	damage_done.set_value("%.1f" % stats.damage_done)
	health_lost.set_value("%.1f" % stats.health_lost)
	
func _on_next_pressed() -> void:
	var stats := RoundStatTracker.round_data

	if stats and stats.won:
		SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
	else:
		SceneManager.restart_level()
