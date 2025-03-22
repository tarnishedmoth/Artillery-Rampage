class_name GameTimer extends Node

var _time_seconds:float = 0.0  # Elapsed game time in seconds

func _init() -> void:
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE
	
var time_seconds: float:
	get:
		return _time_seconds

var time_ms: float:
	get:
		return _time_seconds * 1000

func _process(delta: float) -> void:
	_time_seconds += delta
	# print_debug("TimeSeconds=%fs; EngineTime=%fs" % [_time_seconds, Time.get_ticks_msec() / 1000.0])
