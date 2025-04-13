class_name StoryRoundSummary extends Control

@export var win_background:Texture
@export var lose_background:Texture

@onready var background:TextureRect = %Background
@onready var title:HUDElement = %Title
@onready var turns:HUDElement = %Turns
@onready var kills:HUDElement = %Kills
@onready var damage_done:HUDElement = %DamageDone
@onready var health_lost:HUDElement = %HealthLost

@onready var tooltipper:TextSequence = %StoryTooltips
@onready var auto_narrative:AutoNarrative = %AutoNarrative

@onready var win_audio: AudioStreamPlayer = %RoundWinAudio
@onready var lose_audio: AudioStreamPlayer = %RoundLoseAudio

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
		
	_set_narrative()
	
	turns.set_value(stats.turns)
	kills.set_value(stats.kills)
	damage_done.set_value("%.1f" % stats.damage_done)
	health_lost.set_value("%.1f" % (stats.max_health - stats.final_health))
	
	_play_audio()
	
func _on_next_pressed() -> void:
	var stats := RoundStatTracker.round_data

	if stats and stats.won:
		SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
	else:
		SceneManager.restart_level()

func _play_audio() -> void:
	if RoundStatTracker.round_data.won:
		win_audio.play()
	else:
		lose_audio.play()
		
#region Auto Narrative

func _set_narrative() -> void:
	var text_control:Control = tooltipper.sequence.back()
	
	var outcome := _calculate_outcome()
	var narrative:String = auto_narrative.generate_narrative(outcome)
	text_control.get_child(0).text = narrative

func _calculate_outcome() -> AutoNarrative.Outcomes:
	# If won look at damage ratio and take into account kills
	# TODO: For miracle, track damage done and kills at low health - probably need to bracket into percentiles (not dictionary with float)
	# That tracks damage_done and kills at each health level
	var stats := RoundStatTracker.round_data
	
	# Damage to health lost ratio
	var damage_to_health:float = stats.damage_done / maxf(stats.max_health - stats.final_health, 1.0)
		
	if stats.won:
		# Miracles are actually decisive victories not crazy come from behind victories
		#if stats.final_health / stats.max_health < 0.1:
			#return AutoNarrative.Outcomes.MIRACLE
		if damage_to_health >= 10.0 and stats.kills > 1:
			return AutoNarrative.Outcomes.MIRACLE	
		if damage_to_health > 1.0:
			return AutoNarrative.Outcomes.SUCCESS
		return AutoNarrative.Outcomes.NEUTRAL
	#Lost
	if damage_to_health >= 0.5:
		return AutoNarrative.Outcomes.FAILURE
	return AutoNarrative.Outcomes.CATASTROPHE
	
#endregion
