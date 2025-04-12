class_name StoryRoundSummary extends Control

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
	title.set_value("Victory!" if stats.won else "Defeat :(")
	
	turns.set_value(stats.turns)
	kills.set_value(stats.kills)
	damage_done.set_value("%.1f" % stats.damage_done)
	health_lost.set_value("%.1f" % stats.health_lost)
	
func _on_next_pressed() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
