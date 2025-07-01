class_name DayWeather extends Node

signal transitioned

enum TOD {
	Morning,
	Noon,
	Afternoon,
	Night
}

@export var randomize_starting_tod:bool = true

@export var current_tod:TOD = TOD.Morning
@export var day_length:float = 240.0
var day_segment:float:
	get: return day_length / enabled_tods.size()

@export var morning:Vector2 = Vector2(-400.0, 240.0):
	get: return starting_position + morning
@export var noon: Vector2 = Vector2(0.0, -140.0):
	get: return starting_position + noon
@export var afternoon: Vector2 = Vector2(400.0, 0.0):
	get: return starting_position + afternoon

@export var enabled_tods:Array[TOD]

@export var sun_light:PointLight2D
@export var game_level:GameLevel

@export_group("Light Levels")
@export var day_environment:Color = Color8(230, 230, 230, 255)
@export var night_environment:Color = Color8(40, 50, 70, 255)
var is_night:bool = true ## Status of the environment/modulate, not necessarily "TOD"

@onready var starting_position:Vector2 = sun_light.position
@onready var max_energy:float = sun_light.energy

var tween:Tween
var environment_modulate:Tween

func _ready() -> void:
	if randomize_starting_tod:
		current_tod = enabled_tods.pick_random()
		
	## Setup for start
	if current_tod != TOD.Night:
		day()
		
	match current_tod:
		TOD.Morning:
			sun_light.position = morning
		TOD.Noon:
			sun_light.position = noon
		TOD.Afternoon:
			sun_light.position = afternoon
		TOD.Night:
			night()
			
	await GameEvents.round_started
	if is_night:
		GameEvents.is_nighttime.emit(true)
	else:
		GameEvents.is_nighttime.emit(false)
		
	await get_tree().create_timer(day_segment).timeout
	cycle()
	
func cycle() -> void:
	var picking:bool = true
	while picking:
		match current_tod:
			TOD.Morning:
				current_tod = TOD.Noon
				if TOD.Noon in enabled_tods:
					if is_night:
						day(true)
					change_position(noon, day_segment)
					
				else:
					current_tod = TOD.Noon
					continue
			TOD.Noon:
				current_tod = TOD.Afternoon
				if TOD.Afternoon in enabled_tods:
					if is_night:
						day(true)
					change_position(afternoon, day_segment)
					
				else:
					continue
					
			TOD.Afternoon:
				current_tod = TOD.Night
				if TOD.Night in enabled_tods:
					night(!is_night)
					change_position(noon, day_segment)
					
				else:
					continue
					
			TOD.Night:
				current_tod = TOD.Morning
				if TOD.Morning in enabled_tods:
					if is_night:
						day(true)
					change_position(morning, day_segment)
					
				else:
					continue
					
		picking = false
		
	await transitioned
		
	print_debug("Current day cycle is ", current_tod)
	cycle()
	
func change_position(new_position:Vector2, hold:float) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(sun_light, ^"energy", 0.0, transition_time())
	tween.tween_property(sun_light, ^"position", new_position, transition_time())
	tween.tween_property(sun_light, ^"energy", max_energy, transition_time())
	tween.tween_interval(hold)
	tween.tween_callback(transitioned.emit)


func night(transition:bool = false) -> void:
	if environment_modulate: environment_modulate.kill()
	is_night = true
	GameEvents.is_nighttime.emit(true)
	
	if transition:
		environment_modulate = create_tween()
		environment_modulate.tween_property(game_level, ^"modulate", night_environment, transition_time())
	else:
		game_level.modulate = night_environment

func day(transition:bool = false) -> void:
	if environment_modulate: environment_modulate.kill()
	is_night = false
	GameEvents.is_nighttime.emit(false)
	
	if transition:
		environment_modulate = create_tween()
		environment_modulate.tween_property(game_level, ^"modulate", day_environment, transition_time())
	else:
		game_level.modulate = day_environment

func transition_time() -> float:
	return randf_range(Juice.LONG, Juice.VERYLONG)
