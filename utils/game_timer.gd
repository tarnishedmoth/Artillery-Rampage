class_name GameTimer extends Node

var _time_seconds:float = 0.0  # Elapsed game time in seconds
var _frame_count:int = 0

func _init() -> void:
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE
	
var time_seconds: float:
	get:
		return _time_seconds

var time_ms: float:
	get:
		return _time_seconds * 1000

var frame:int:
	get: return _frame_count
	
func _process(delta: float) -> void:
	_time_seconds += delta
	_frame_count += 1
	
	RenderingServer.global_shader_parameter_set(&"game_time", _time_seconds)
