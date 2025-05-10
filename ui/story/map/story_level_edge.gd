class_name StoryLevelEdge extends Node2D

@export_group("Edge")
@export var from:Vector2
@export var to:Vector2

@export var color:Color
@export var line_width:float = 3

@export_range(1.0, 100.0, 1.0)
var arrow_head_length:float = 20.0

@export_range(0, 20)
var num_arrow_animations:int = 10

@export
var arrow_animation_time_range:Vector2 = Vector2(1.5, 2.0)

@export var arrow_head_width:float = 4

@export_range(1.0, 90.0, 1.0)
var arrow_angle_deg:float = 45.0

func _ready() -> void:
	if num_arrow_animations > 0:
		for i in num_arrow_animations:
			var arrow_scale:float = 1.0 / (num_arrow_animations - i)
			var animation_duration:float = lerpf(arrow_animation_time_range.y, arrow_animation_time_range.x, i / maxf(1.0, num_arrow_animations - 1))

			add_child(_create_arrow_head(animation_duration, arrow_scale))
	else:
		add_child(_create_arrow_head(-1.0, 1.0))

func _draw() -> void:
	_draw_edge_line()

func _draw_edge_line() -> void:
	draw_line(from, to, color, line_width)

func _create_arrow_head(animation_time:float, in_scale:float) -> ArrowHead:
	var arrow:ArrowHead = ArrowHead.new()

	arrow.name = "Arrow"
	arrow.from = from
	arrow.to = to
	arrow.color = color
	arrow.arrow_head_width = arrow_head_width * in_scale
	arrow.arrow_head_length = arrow_head_length * in_scale
	arrow.arrow_angle_deg = arrow_angle_deg
	arrow.animation_duration = animation_time

	return arrow
