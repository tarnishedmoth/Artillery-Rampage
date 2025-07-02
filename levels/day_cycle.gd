class_name DayWeather extends Node

signal sun_transitioned
signal env_transitioned
signal transitioned
signal cycle_completed

## Morning: 0, Noon: 1, Afternoon: 2, Night: 3
enum TOD {
	Morning = 0,
	Noon = 1,
	Afternoon = 2,
	Night = 3
}
enum ENV {
	Day = 0,
	Night = 1
}

#class DayWeatherState extends Resource:
	#var sun_position:Vector2
	#var ambient_color:Color
	#var is_dark:bool ## Signals things with lights to respond.

@export var randomize_starting_tod:bool = true ## Overrides current_tod on match start if true.

@export var day_length:float = 240.0 ## In seconds, an entire day cycle. See [member day_segment].
## Divides the [member day_length] by the number of entries in [member enabled_tods].
var day_segment:float:
	get: return day_length / enabled_tods.size()

@export var enabled_tods:Array[TOD]
#@export var presets_queue:Array[DayWeatherState]

@export var current_tod:TOD = TOD.Morning

@export_group("Sun Positions")
@export var morning:Vector2 = Vector2(-400.0, 240.0):
	get: return starting_position + morning
@export var noon: Vector2 = Vector2(0.0, -140.0):
	get: return starting_position + noon
@export var afternoon: Vector2 = Vector2(400.0, 0.0):
	get: return starting_position + afternoon

@export_group("Light Levels")
@export var day_environment:Color = Color8(230, 230, 230, 255)
@export var night_environment:Color = Color8(40, 50, 70, 255)
var is_night:bool = true ## Status of the environment/modulate, not necessarily "TOD"

@export_group("Export Nodes")
@export var sun_light:PointLight2D
@export var game_level:GameLevel

@onready var starting_position:Vector2 = sun_light.position
@onready var max_energy:float = sun_light.energy

#var state_queue:Array[DayWeatherState]

var _awaiting_transitions:int = 0
var environment_tween:Tween
var sun_position_tween:Tween

var _transitions_lengths:Dictionary[StringName, float] = {}
var sum:Callable = func(a,b): return a+b

var tod_change_timer:Timer

func _enter_tree() -> void:
	tod_change_timer = Timer.new()
	tod_change_timer.one_shot = true # We're manually starting and stopping
	add_child(tod_change_timer)
	tod_change_timer.timeout.connect(next_tod)
	
#func reset_queue() -> void:
	#state_queue.clear()
	#state_queue.append_array(presets_queue)

func _ready() -> void:
	#reset_queue()
	
	if randomize_starting_tod:
		current_tod = enabled_tods.pick_random()
		
	## Setup for start
	match current_tod:
		TOD.Morning:
			sun_light.position = morning
			switch_environment(ENV.Day, true)
		TOD.Noon:
			sun_light.position = noon
			switch_environment(ENV.Day, true)
		TOD.Afternoon:
			sun_light.position = afternoon
			switch_environment(ENV.Day, true)
		TOD.Night:
			sun_light.position = noon
			switch_environment(ENV.Night, true)
			
	await GameEvents.round_started
	
	GameEvents.tod_changed.emit(current_tod, 3.0)
	
	this_tod()
	
func this_tod() -> void:
	tod_change_timer.start(day_segment)
	print_debug("The current day cycle is ", TOD.find_key(current_tod))

func next_tod() -> void:
	_transitions_lengths.clear()
	var picking:bool = true
	while picking:
		
		match current_tod:
			TOD.Morning:
				current_tod = TOD.Noon
				if TOD.Noon in enabled_tods:
					if is_night: switch_environment(ENV.Day)
					move_sun(noon)
					break
				else:
					continue
					
			TOD.Noon:
				current_tod = TOD.Afternoon
				if TOD.Afternoon in enabled_tods:
					if is_night: switch_environment(ENV.Day)
					move_sun(afternoon)
					break
				else:
					continue
					
			TOD.Afternoon:
				current_tod = TOD.Night
				if TOD.Night in enabled_tods:
					if not is_night: switch_environment(ENV.Night)
					move_sun(noon)
					break
				else:
					continue
					
			TOD.Night:
				current_tod = TOD.Morning
				if TOD.Morning in enabled_tods:
					if is_night: switch_environment(ENV.Day)
					move_sun(morning)
					break
				else:
					continue
	GameEvents.tod_changed.emit(current_tod, _transitions_lengths.values().reduce(sum))
	await transitioned
	this_tod()
	
	
func move_sun(new_position:Vector2) -> void: #, hold:float) -> Tween:
	print("MOVE SUN")
	_awaiting_transitions += 1
	
	# Make 3 random numbers and record the total length of time this tween will take.
	var transitions_durations:Array[float] = []
	var _sum:float
	for i in 3:
		var time:float = transition_time()
		transitions_durations.append(time)
		
		_sum += time
	_transitions_lengths["sun"] = _sum
	
	if sun_position_tween:
		if sun_position_tween.is_running():
			sun_position_tween.kill()
	sun_position_tween = create_tween()
	
	sun_position_tween.tween_property(sun_light, ^"energy", 0.0, transitions_durations.pop_back())
	sun_position_tween.tween_property(sun_light, ^"position", new_position, transitions_durations.pop_back())
	sun_position_tween.tween_property(sun_light, ^"energy", max_energy, transitions_durations.pop_back())
	sun_position_tween.tween_callback(_on_transition_completed)
	
	
func switch_environment(env_type:ENV, immediate:bool = false) -> void:
	var mod_color:Color
	match env_type:
		ENV.Day:
			mod_color = day_environment
			is_night = false
		ENV.Night:
			mod_color = night_environment
			is_night = true
	
	print("TRANSITION ENVIRONMENT")
	_awaiting_transitions += 1
	
	if environment_tween:
		if environment_tween.is_running():
			environment_tween.kill()
	
	
	if not immediate:
		var time:float = transition_time()*3.0
		_transitions_lengths["env"] = time
		
		environment_tween = create_tween()
		environment_tween.tween_property(game_level, ^"modulate", mod_color, time)
		environment_tween.tween_callback(_on_transition_completed)
		
	else:
		game_level.modulate = mod_color
		_on_transition_completed.call_deferred()
		

func transition_time() -> float:
	return randf_range(Juice.LONG, Juice.VERYLONG)

func _on_transition_completed() -> void:
	_awaiting_transitions -= 1
	if _awaiting_transitions == 0:
		transitioned.emit()
