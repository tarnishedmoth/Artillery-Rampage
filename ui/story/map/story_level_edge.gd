class_name StoryLevelEdge extends Node2D

@export_group("Edge")
@export var from:Vector2
@export var to:Vector2

@export var color:Color
@export var line_width:float = 3

@export_range(1.0, 100.0, 1.0)
var arrow_head_length:float = 20.0

@export var arrow_head_width:float = 4

@export_range(1.0, 90.0, 1.0)
var arrow_angle_deg:float = 45.0

func _draw() -> void:
	# Draw the main line
	draw_line(from, to, color, line_width)

	# Calculate the direction vector
	var arrow_angle_rads:float = deg_to_rad(arrow_angle_deg)
	var direction:Vector2 = (to - from).normalized()

	# Calculate the arrowhead points
	var left_arrow:Vector2 = to - direction.rotated(arrow_angle_rads) * arrow_head_length
	var right_arrow:Vector2 = to - direction.rotated(-arrow_angle_rads) * arrow_head_length

	# Draw the arrowhead
	draw_line(to, left_arrow, color, arrow_head_width)
	draw_line(to, right_arrow, color, arrow_head_width)
