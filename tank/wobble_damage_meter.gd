class_name WobbleDamagerMeter extends Node2D

## Connect the AimDamableWobble node
@export
var aim_damage_wobble: AimDamageWobble

@export
var marker_circle_arc_angle_deg:float = 15

@export
var indicator_color:Color = Color.BLACK

@export
var indicator_width:float = 3.0

@onready var bar: TextureRect = $TextureRect

@onready var top_line_pos:Marker2D = $TopLinePos
@onready var bottom_line_pos:Marker2D = $BottomLinePos
@onready var right_line_pos:Marker2D = $RightLinePos
@onready var left_line_pos:Marker2D = $LeftLinePos

var _deviation:float = 0.0
var _marker_circle_arc_angle_rads:float
var _dy:float

func _ready() -> void:
	if SceneManager.is_precompiler_running:
		return
	if not aim_damage_wobble:
		push_error("%s - Missing configuration; aim_damage_wobble=%s" % [name, aim_damage_wobble])
		return
	
	_dy = absf(bottom_line_pos.position.y - top_line_pos.position.y)
	_marker_circle_arc_angle_rads = deg_to_rad(marker_circle_arc_angle_deg * 0.5)
	
	aim_damage_wobble.wobble_updated.connect(_on_wobble_updated)
	
func _on_wobble_updated() -> void:
	_deviation = aim_damage_wobble.deviation_alpha
	
	queue_redraw()
	
func _draw() -> void:
	# Aim wobble has 4 equal phases
	# 1 - Center to left, 2 - Left to center, 3 - Center to right, 4 - Right to center
	var quarter:float = _deviation * 4.0
	# Get quarter fraction
	var phase_deviation:float = fmod(quarter, 1.0)
	var phase:int = ceili(quarter)
	
	var x_alpha:float 
	var angle:float
	
	match phase:
		1:
			x_alpha = lerpf(0.5, 0.0, phase_deviation)
			angle = lerpf(0.0, -phase_deviation * _marker_circle_arc_angle_rads, phase_deviation)
		2:
			x_alpha = lerpf(0.0, 0.5, phase_deviation)
			angle = lerpf(-_marker_circle_arc_angle_rads, 0.0, x_alpha)
		3: 
			x_alpha = lerpf(0.5, 1.0, phase_deviation)
			angle = lerpf(0.0, _marker_circle_arc_angle_rads, phase_deviation)
		_: #4
			x_alpha = lerpf(1.0, 0.5, phase_deviation)
			angle = lerpf(_marker_circle_arc_angle_rads, 0.0, phase_deviation)
		
	var x:float = lerpf(left_line_pos.position.x, right_line_pos.position.x, x_alpha)
	
	var dv:Vector2 = Vector2.UP.rotated(angle) * _dy
	
	var start:Vector2 = Vector2(x, bottom_line_pos.position.y)
	var end:Vector2 = start + dv
	
	draw_line(start, end, indicator_color,indicator_width, true)
	
