class_name DayWeather extends Node

signal sun_transitioned
signal env_transitioned
signal transitioned
signal cycle_completed

const PRECIPITATION_SCENE = preload("res://effects/precipitation.tscn")

@export var randomize_starting_state:bool = true ## Overrides current_tod on match start if true.
@export_enum("Ordered:0", "Random:1") var state_change_logic:int = 0

@export var day_length:float = 240.0 ## In seconds, an entire day cycle. See [member day_segment].
## Divides the [member day_length] by the number of entries in [member presets_queue].
var day_segment:float:
	get: return day_length / presets_queue.size()

@export var presets_queue:Array[DayWeatherState]

var current_state:DayWeatherState

var is_night:bool = true ## Status of the environment/modulate, not necessarily "TOD"

@export_group("Export Nodes")
@export var sun_light:PointLight2D
@export var game_level:GameLevel

@onready var starting_position:Vector2 = sun_light.position
@onready var starting_energy:float = sun_light.energy

var _state_queue:Array[DayWeatherState]

var _awaiting_transitions:int = 0
var environment_tween:Tween
var sun_position_tween:Tween

var _transitions_lengths:Dictionary[StringName, float] = {}
var sum:Callable = func(a,b): return a+b

var next_state_timer:Timer

var _active_weather_node:WeatherEffects

func _enter_tree() -> void:
	next_state_timer = Timer.new()
	next_state_timer.one_shot = true # We're manually starting and stopping
	add_child(next_state_timer)
	next_state_timer.timeout.connect(next_state)
	
func reset_queue() -> void:
	if presets_queue.is_empty():
		push_error("Yah we need some presets pal")
	
	_state_queue.clear()
	_state_queue.append_array(presets_queue)

func _ready() -> void:
	reset_queue()
	
	if randomize_starting_state:
		current_state = _state_queue.pick_random()
		_state_queue = _state_queue.slice(_state_queue.find(current_state))
	else:
		current_state = _state_queue.pop_front()
		
	## Setup for start
	apply_state(current_state, true)
			
	await GameEvents.round_started
	GameEvents.day_weather_changed.emit(current_state, 3.0)
	wait_and_next_state()
	
func wait_and_next_state() -> void:
	next_state_timer.start(current_state.duration_ratio * day_segment)
	if current_state.is_raining:
		print_debug("The current day cycle is ", current_state.display_name, " and it's raining.")
	else:
		print_debug("The current day cycle is ", current_state.display_name)

func next_state() -> void:
	_transitions_lengths.clear()
	
	if _state_queue.is_empty(): reset_queue()
	
	var getting_state:bool = true
	while getting_state:
		var state:DayWeatherState = null
		
		match state_change_logic:
			0: # Ordered
				state = _state_queue.pop_front()
			1: # Random
				state = _state_queue.pick_random()
				_state_queue.erase(state)
			_:
				assert(false, "%s: Unexpected state flag=%d" % [name, state_change_logic])
		
		# If queue is empty state will be null
		if not state:
			if _state_queue.is_empty():
				reset_queue()
			continue
				
		if state.skip_chance > 0.0:
			if randf() < state.skip_chance:
				continue
		
		current_state = state
		getting_state = false
		break
		
	apply_state(current_state)
	
	GameEvents.day_weather_changed.emit(current_state, _transitions_lengths.values().reduce(sum))
	await transitioned
	wait_and_next_state()
	
func apply_state(state:DayWeatherState, immediate:bool = false) -> void:
	if randf() < state.rain_chance:
		# Raining
		state.is_raining = true
		is_night = state.rain_is_dark
		change_ambient(state.rain_ambient_color, immediate)
		change_sun(state.sun_position, state.rain_sun_energy, immediate)
	else:
		# Not raining
		state.is_raining = false
		is_night = state.is_dark
		change_ambient(state.ambient_color, immediate)
		change_sun(state.sun_position, state.sun_energy, immediate)
		
	change_weather(state, immediate)
	
	
func change_sun(new_position:Vector2, new_energy:float = starting_energy, immediate:bool = false) -> void: #, hold:float) -> Tween:
	print("MOVE SUN")
	_awaiting_transitions += 1
	
	if sun_position_tween:
		if sun_position_tween.is_running():
			sun_position_tween.kill()
			
	if not immediate:
		# Make 3 random numbers and record the total length of time this tween will take.
		var transitions_durations:Array[float] = []
		var _sum:float
		for i in 3:
			var time:float = transition_time()
			transitions_durations.append(time)
			
			_sum += time
		_transitions_lengths["sun"] = _sum
		
		sun_position_tween = create_tween()
		sun_position_tween.tween_property(sun_light, ^"energy", 0.0, transitions_durations.pop_back())
		sun_position_tween.tween_property(sun_light, ^"position", starting_position+new_position, transitions_durations.pop_back())
		sun_position_tween.tween_property(sun_light, ^"energy", new_energy, transitions_durations.pop_back())
		sun_position_tween.tween_callback(_on_transition_completed)
	else:
		sun_light.position = starting_position+new_position
		sun_light.energy = new_energy
		_on_transition_completed.call_deferred()
	
	
func change_ambient(mod_color:Color, immediate:bool = false) -> void:
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
		

func change_weather(state:DayWeatherState, immediate:bool) -> void:
	## TODO: tank lights catching particles, terrain chunk sets light occluder on start
	var transition_time:float = 1.0 if immediate else state.weather_transition_time
	
	if state.is_raining:
		# Current state wants rain
		if not _active_weather_node:
			# Node is invalid
			_active_weather_node = PRECIPITATION_SCENE.instantiate()
			add_child(_active_weather_node)
			_active_weather_node.start_rain(state.rain_intensity, transition_time)
			
		else:
			
			# Node is valid
			if _active_weather_node.is_deleting:
				# Still transitioning to delete
				await _active_weather_node.tree_exited
				change_weather(state, immediate)
				return
			else:
				# Chilling
				_active_weather_node.set_rain_intensity(state.rain_intensity, transition_time)
		
	else:
		# Current state wants not rain
		if _active_weather_node:
			_active_weather_node.stop_rain_and_delete(transition_time)


func transition_time() -> float:
	return randf_range(Juice.LONG, Juice.VERYLONG)

func _on_transition_completed() -> void:
	_awaiting_transitions -= 1
	if _awaiting_transitions == 0:
		transitioned.emit()
