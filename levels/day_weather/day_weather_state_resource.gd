class_name DayWeatherState extends Resource

@export var display_name:String ## Only used in the debug console

## Use this for special states like rainstorms if they should be random.
## If zero, the state is always applied when picked by the DayWeather queue.
## Otherwise this bias is used for a coin flip.
@export_range(0.0, 0.99, 0.01) var skip_chance:float = 0.0
## Use this to make shorter or longer than normal day states.
@export_range(0.1, 1.0, 0.1, "or_greater") var duration_ratio:float = 1.0

@export var sun_position:Vector2 = Vector2(640.0, -640.0)
@export var sun_energy:float = 0.33
@export var ambient_color:Color = Color.GHOST_WHITE
@export var is_dark:bool = false ## Signals things with lights to respond.

@export_group("Weather")
@export_range(0.1, 30.0, 0.1, "or_greater") var weather_transition_time:float = 10.0
@export_range(0.0, 1.0, 0.05) var rain_chance:float = 0.0
@export_range(0.1, 1.0, 0.05) var rain_intensity:float = 0.5
@export var rain_ambient_color:Color = Color.MEDIUM_TURQUOISE
@export var rain_sun_energy:float = 0.22
@export var rain_is_dark:bool = true ## Signals things with lights to respond.
@export var use_snow:bool = false ## Replaces the rain with snow.

var is_raining:bool = false
