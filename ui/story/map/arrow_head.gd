class_name ArrowHead extends Node2D

@export_group("ArrowHead")
@export var from:Vector2
@export var to:Vector2

@export var color:Color

@export_range(1.0, 100.0, 1.0)
var arrow_head_length:float = 20.0

@export var arrow_head_width:float = 4

@export_range(1.0, 90.0, 1.0)
var arrow_angle_deg:float = 45.0

@export
var animation_duration:float = -1.0

var _left_arrow_head_dir:Vector2
var _right_arrow_head_dir:Vector2

var _progress:float:
	get: return _progress
	set(value):
		_progress = value
		queue_redraw()

func _ready() -> void:
	var arrow_angle_rads := deg_to_rad(arrow_angle_deg)
	var direction:Vector2 = (to - from).normalized()

	_left_arrow_head_dir = direction.rotated(arrow_angle_rads)
	_right_arrow_head_dir = direction.rotated(-arrow_angle_rads)

	if animation_duration > 0:
		_start_arrow_tween()
	else:
		_progress = 1.0

func _start_arrow_tween() -> void:
	_progress = 0.0
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, animation_duration)
	tween.finished.connect(_on_tween_finished)

func _on_tween_finished() -> void:
	_start_arrow_tween()

func _draw() -> void:
	var arrow_pt:Vector2 = from.lerp(to, _progress)

	_draw_arrow(arrow_pt, arrow_head_length)

func _draw_arrow(point:Vector2, head_length: float) -> void:
	# Calculate the arrowhead points
	var left_arrow:Vector2 = point - _left_arrow_head_dir * head_length
	var right_arrow:Vector2 = point - _right_arrow_head_dir * head_length

	# Draw the arrowhead
	draw_line(point, left_arrow, color, arrow_head_width)
	draw_line(point, right_arrow, color, arrow_head_width)
