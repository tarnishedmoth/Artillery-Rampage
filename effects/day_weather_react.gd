extends Node

@export var lights:Array[CanvasItem]

func _ready() -> void:
	GameEvents.day_weather_changed.connect(_on_dayweather_changed)
	for light in lights:
		light.hide()

func _on_dayweather_changed(new_state:DayWeatherState, transition_time:float) -> void:
	await get_tree().create_timer(randfn(transition_time/2.0, transition_time/5.0)).timeout
	
	for light in lights:
		if not new_state.is_raining:
			light.visible = new_state.is_dark
		else:
			light.visible = new_state.rain_is_dark
