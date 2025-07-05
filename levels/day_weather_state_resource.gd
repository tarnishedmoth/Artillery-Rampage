class_name DayWeatherState extends Resource

@export var display_name:String ## Only used in the debug console
@export var sun_position:Vector2 = Vector2(640.0, -640.0)
@export var sun_energy:float = 0.33
@export var ambient_color:Color = Color.GHOST_WHITE
@export var is_dark:bool = false ## Signals things with lights to respond.

@export_group("Weather")
@export var is_raining:bool = false
@export_range(0.1, 1.0, 0.1) var rain_intensity:float = 0.5
