class_name StoryRoundSummary extends Control

@export var win_background:Texture
@export var lose_background:Texture

@onready var background:TextureRect = %Background
@onready var title:HUDElement = %Title
@onready var turns:HUDElement = %Turns
@onready var kills:HUDElement = %Kills
@onready var damage_done:HUDElement = %DamageDone
@onready var health_lost:HUDElement = %HealthLost
@onready var grade:HUDElement = %Grade
@onready var personnel:HUDElement = %Personnel
@onready var scrap:HUDElement = %Scrap

@onready var tooltipper:TextSequence = %StoryTooltips
@onready var auto_narrative:AutoNarrative = %AutoNarrative

@onready var win_audio: AudioStreamPlayer = %RoundWinAudio
@onready var lose_audio: AudioStreamPlayer = %RoundLoseAudio

var _grade:int = 0
var _is_game_over:bool = false

static var letter_to_grade:Dictionary[String, int]
static var grade_to_letter:Dictionary[int, String]

static func _static_init():
	var grades: Array[String] = [
		"A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D+", "D", "D-", "F"
	]
	# Lowest grade is a Zero
	grades.reverse()
	
	for i in grades.size():
		letter_to_grade[grades[i]] = i
		grade_to_letter[i] = grades[i]

func _ready() -> void:
	var stats : RoundStatTracker.RoundData = RoundStatTracker.round_data
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
				
	_grade = _calculate_grade()
	# Hiding grade if you lose
	if stats.won:
		grade.set_value(_fmt_grade(_grade))
	else:
		grade.hide()
		
	_set_narrative(_grade)
	
	turns.set_value(stats.turns)
	kills.set_value(stats.kills)
	damage_done.set_value("%.1f" % stats.damage_done)
	# Show health lost bot has absolute value and percentage of max
	var health_lost_amount:float = stats.start_health - stats.final_health
	health_lost.set_value(UIUtils.get_health_pct_display(health_lost_amount, stats.max_health))
	
	_play_audio()
	
	_update_attributes.call_deferred()

func _update_attributes() -> void:
	var stats : RoundStatTracker.RoundData = RoundStatTracker.round_data
	if not stats:
		return
		
	# TODO: Make this more dynamic - use curves
	var personnel_change:int = 0

	# Player gets scrap even when lose based on collected data
	var scrap_change:int = _calculate_scrap_earned()

	if stats.won:
		# Nerfing personnel gained by diving by 3 instead of 2
		personnel_change = ceil(_grade / 3.0)
	else:
		personnel_change =  -floori((grade_to_letter.size() - _grade) / 4.0)

	PlayerAttributes.personnel = maxi(PlayerAttributes.personnel + personnel_change, 0)
	PlayerAttributes.scrap = maxi(PlayerAttributes.scrap + scrap_change, 0)

	personnel.set_value(_fmt_attr(PlayerAttributes.personnel, personnel_change))
	scrap.set_value(_fmt_attr(PlayerAttributes.scrap, scrap_change))

	# TODO: Maybe do this from StatTracker as player could game the system and quit here and it wouldn't save
	# Here we are explicitly forcing a save
	SaveStateManager.save_tree_state(&"StoryLevelFinished")

	_is_game_over = PlayerAttributes.personnel <= 0

func _calculate_scrap_earned() -> int:
	var stats : RoundStatTracker.RoundData = RoundStatTracker.round_data
	assert(stats, "_calculate_scrap_earned called without round data!")

	# Earn 3 scrap for a full kill (player killed opponent and caused all the damage except for tank self damage)
	# Earn 2 scrap for a partial kill (player killed opponent but some other opponent caused some damage)
	# Earn 1 scrap for any damage to opponent

	var earned_scrap:int = 0
	for key in stats.enemies_damaged:
		var enemy_data:RoundStatTracker.EnemyData = stats.enemies_damaged[key]
		if enemy_data.is_full_kill():
			earned_scrap += 3
			print_debug("%s: Awarding 3 scrap for full kill against %s" % [name, enemy_data.name])
		elif enemy_data.is_partial_kill():
			earned_scrap += 2
			print_debug("%s: Awarding 2 scrap for partial kill against %s" % [name, enemy_data.name])
		elif enemy_data.is_damaged():
			earned_scrap += 1

			print_debug("%s: Awarding 1 scrap for some damage against %s" % [name, enemy_data.name])
	return earned_scrap

func _on_next_pressed() -> void:
	var stats : RoundStatTracker.RoundData = RoundStatTracker.round_data

	if stats and stats.won:
		_next_after_win()
	elif not _is_game_over:
		_next_after_loss()
	else:
		SceneManager.switch_scene_keyed(SceneManager.SceneKeys.GameOver)

func _next_after_loss() -> void:
	# If player state is defined make sure we restart with full health as already took the personnel hit
	var player_state:PlayerState = PlayerStateManager.player_state
	if player_state:
		player_state.health = player_state.max_health
	else:
		push_warning("%s: No player state was defined when restarting level - unable to reset player health" % name)

	# TODO: May want to only go to shop if have resources to spend
	# Can handle this by queueing the transition and then dequeue_transition which will work for both cases
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryShop)

	# Queue next transition after this
	SceneManager.queue_transition("restart_level")

func _next_after_win() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.UpgradeSelect)

	# Queue next transitions after this
	SceneManager.queue_transition("switch_scene_keyed", [SceneManager.SceneKeys.StoryShop])

	# Check if on last level of run and trigger the run end screen instead in that case
	if SceneManager.is_on_last_story_level():
		SceneManager.queue_transition("switch_scene_keyed", [SceneManager.SceneKeys.StoryComplete])
	else:
		SceneManager.queue_transition("switch_scene_keyed", [SceneManager.SceneKeys.StoryMap])

func _play_audio() -> void:
	if RoundStatTracker.round_data.won:
		win_audio.play()
	else:
		lose_audio.play()
		
#region Auto Narrative

func _set_narrative(grade: int) -> void:
	var text_control:Control = tooltipper.sequence.back()
	
	var outcome := _calculate_outcome(grade)
	var narrative:String = auto_narrative.generate_narrative(outcome)
	text_control.get_child(0).text = narrative

func _calculate_outcome(grade: int) -> AutoNarrative.Outcomes:
	match _fmt_grade(grade):
		"A+", "A", "A-" : return AutoNarrative.Outcomes.MIRACLE
		"B+", "B", "B-": return AutoNarrative.Outcomes.SUCCESS
		"C+", "C", "C-" : return AutoNarrative.Outcomes.NEUTRAL
		"D+", "D", "D-" : return AutoNarrative.Outcomes.FAILURE
	return AutoNarrative.Outcomes.CATASTROPHE
	
#endregion

#region Scoring

		
func _fmt_grade(grade: int) -> String:
	return grade_to_letter.get(grade, "A+")
		
func _fmt_attr(value: int, delta:int) -> String:
	if delta > 0:
		return "%d (+%d)" % [value, delta]
	elif delta < 0:
		return "%d (%d)" % [value, delta]
	else:
		return "%d (+0)" % value
		
func _calculate_grade() -> int:
	# If won look at damage ratio and take into account kills
	# TODO: For miracle, track damage done and kills at low health - probably need to bracket into percentiles (not dictionary with float)
	# That tracks damage_done and kills at each health level
	var stats : RoundStatTracker.RoundData = RoundStatTracker.round_data

	# Damage to health lost ratio
	var damage_to_health:float = stats.damage_done / maxf(stats.start_health - stats.final_health, 1.0)
	var kills_to_turns: float = stats.kills / maxf(stats.turns, 1.0)
	
	var grade:int = 0

	# Lowest win is C-	
	if stats.won:
		# Miracles are actually decisive victories not crazy come from behind victories
		if is_zero_approx(stats.health_lost):
			if stats.kills >= 3:
				grade = letter_to_grade["A+"]
			if stats.kills >= 1:
				grade = letter_to_grade["A"]
			else:
				grade = letter_to_grade["B+"]
		elif damage_to_health >= 10.0 and stats.kills >= 2:
			grade = letter_to_grade["A"]
		elif damage_to_health >= 5.0 and stats.kills >= 1:
			grade = letter_to_grade["A-"]
		elif damage_to_health > 1.0:
			grade = letter_to_grade["B+"]
		elif damage_to_health >= 0.75:
			grade = letter_to_grade["B"]
		elif damage_to_health > 0.5:
			grade = letter_to_grade["B-"]
		else:
			grade = letter_to_grade["C"]
			
		if kills_to_turns > 1:
			grade += 3
		elif is_equal_approx(kills_to_turns, 1.0):
			grade += 2
		elif kills_to_turns >= 0.5:
			grade += 1
		elif kills_to_turns > 0 and kills_to_turns < 0.25:
			grade -= 1
		else:
			grade -= 2
			
		# Need at least a neutral for winning
		return maxi(grade, letter_to_grade["C-"])
		
	#Lost
	
	if stats.kills >= 3:
		grade = letter_to_grade["C+"]
	elif stats.kills >= 2:
		grade = letter_to_grade["C"]
	elif stats.kills >= 1:
		grade = letter_to_grade["C-"]		
		
	if damage_to_health >= 5:
		grade += 6
	elif damage_to_health >= 3.0:
		grade += 3
	elif damage_to_health >= 2.0:
		grade += 2
	elif damage_to_health >= 1.0:
		grade += 1
	elif damage_to_health >= 0.75:
		# no effect on grade use case to simplify conditionals
		pass
	elif damage_to_health >= 0.5:
		grade -= 1 	
	elif damage_to_health >= 0.35:
		grade -= 2 	
	elif damage_to_health >= 0.25:
		grade -= 3
	elif damage_to_health >= 0.1:
		grade -= 4
	elif stats.damage_done > 0:
		grade -= 5
	else:
		grade -= 6
		
	# If you lose you cannot get higher than a D+
	return clampi(grade, 0, letter_to_grade["D+"])
#endregion
