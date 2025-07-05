class_name PrecipitationAudio extends Node2D

const MIN_CYCLE:float = 2.0
const MAX_CYCLE:float = 0.1

@onready var asp: AudioStreamPlayer = $AudioStreamPlayer2D
@onready var timer: Timer = $Timer

var period:float = 0.5
var intensity_tween:Tween

func start(transition_time:float, intensity:float) -> void:
	period = MIN_CYCLE
	tween_period(transition_time, MAX_CYCLE*intensity)
	timer.start(_random())
	
func stop(transition_time:float) -> void:
	tween_period(transition_time, 2.0)
	intensity_tween.tween_callback(timer.stop)
	
func tween_period(transition_time:float, value:float) -> void:
	if intensity_tween:
		if intensity_tween.is_running():
			intensity_tween.kill()
			
	value = clampf(value, MAX_CYCLE, MIN_CYCLE)
	intensity_tween = create_tween()
	intensity_tween.tween_property(self, ^"period", value, transition_time)

func _on_timer_timeout() -> void:
	asp.play()
	timer.start(_random())
	
func _random() -> float:
	return randfn(period, clampf(period/4, 0.05, 0.5))
