extends Control

## Designed to cycle tooltips and other sorts of UI things.

@export var sequence: Array[Control] ## The control nodes you want to manipulate.
@export var cycle_time: float = 2.9 ## In seconds, each item is displayed this long before cycling.

var currently_visible_control: Control
var current_sequence: Array
var _current_sequence_index: int
var _timer: Timer

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if not sequence.is_empty():
		start_sequence(sequence)
	
func start_sequence(array:Array) -> void:
	current_sequence = array
	for control in array:
		control.hide()
		
	currently_visible_control = current_sequence.front()
	currently_visible_control.show()
	_current_sequence_index = 0
	
	if _timer:
		_timer.queue_free()
		await _timer.tree_exited
	
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_on_cycle_timeout)
	_timer.start(cycle_time)
	
func advance_sequence() -> void:
	# Linear forward
	if _current_sequence_index + 1 < current_sequence.size():
		_current_sequence_index += 1
	else:
		_current_sequence_index = 0
	currently_visible_control.hide()
	currently_visible_control = current_sequence[_current_sequence_index]
	currently_visible_control.show()

func stop() -> void:
	_timer.queue_free()
	
func pause() -> void:
	_timer.stop()
	
func resume() -> void:
	_timer.start(cycle_time)
	
func _on_cycle_timeout() -> void:
	advance_sequence()

func _on_visibility_changed() -> void:
	if _timer:
		if visible:
			resume()
		else:
			pause()
