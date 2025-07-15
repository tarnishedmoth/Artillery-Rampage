class_name TextSequence extends Control

## Designed to cycle tooltips and other sorts of UI things.

@export var sequence: Array[Control] ## The control nodes you want to manipulate.
@export var cycle_time: float = 2.9 ## In seconds, each item is displayed this long before cycling.

var currently_visible_control: Control
var current_sequence: Array
var _current_sequence_index: int
var _timer: Timer
var starting:bool

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	restart_sequence()

func restart_sequence() -> void:
	if not sequence.is_empty():
		start_sequence(sequence)
		
func start_sequence(array:Array) -> void:
	if array.size() == 1:
		array[0].show() 
	else:
		current_sequence = array
		for control in array:
			control.hide()

		currently_visible_control = current_sequence.front()
		currently_visible_control.show()
		_current_sequence_index = 0

	if _timer:
		# Capture the timer in the async stack so if it's called again without awaiting the timer still can be removed
		var timer := _timer
		_timer = null
		timer.queue_free()
		await timer.tree_exited

	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_on_cycle_timeout)
	_timer.start(cycle_time)

func remove_from_sequence(element:Control) -> void:
	var index:int = sequence.find(element)
	if index == -1:
		push_warning("%s: Attempted to remove non-existent control=%s from sequence" % [name, element])
		return
		
	sequence.remove_at(index)
	
	# Need to show next element in sequence if removing the currently active control
	# This is actually now the current active index
	if element == currently_visible_control:
		if not sequence.is_empty():
			_show_current_sequence_index()
			resume()
		else: #Nothing can be shown
			stop()
	
	element.queue_free()	

	
func advance_sequence() -> void:
	# Linear forward
	if _current_sequence_index + 1 < current_sequence.size():
		_current_sequence_index += 1
	else:
		_current_sequence_index = 0

	_show_current_sequence_index()

func _show_current_sequence_index() -> void:
	if is_instance_valid(currently_visible_control):
		currently_visible_control.hide()
	
	if _current_sequence_index >= 0 and _current_sequence_index < current_sequence.size():
		currently_visible_control = current_sequence[_current_sequence_index]
		currently_visible_control.show()
	else:
		currently_visible_control = null
		_current_sequence_index = -1
	
func stop() -> void:
	if _timer:
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
