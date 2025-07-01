extends Node

signal transitioned

## very simple, just oscillate around over time and change the energy output

var duration:float = 240.0

@export var morning:Vector2 = Vector2(-320.0, 120.0):
	get: return starting_position + morning

@export var noon: Vector2 = Vector2(0.0, -120.0):
	get: return starting_position + noon

@export var sunset: Vector2 = Vector2(320.0, 120.0):
	get: return starting_position + sunset

@onready var starting_position:Vector2 = get_parent().position
@onready var max_energy:float = get_parent().energy

var tween:Tween

func _ready() -> void:
	get_parent().position = morning
	await get_tree().create_timer(duration/3.0)
	cycle()
	
func cycle() -> void:
	change_position(noon, duration/3.0)
	await transitioned
	change_position(sunset, duration/3.0)
	await transitioned
	change_position(morning, duration/3.0)
	await transitioned
	cycle()
	
func change_position(new_position:Vector2, hold:float) -> void:
	var parent:PointLight2D = get_parent()
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(parent, ^"energy", 0.0, randf_range(Juice.LONG, Juice.VERYLONG))
	tween.tween_property(parent, ^"position", new_position, randf_range(Juice.SNAPPY, Juice.VERYLONG))
	tween.tween_property(parent, ^"energy", max_energy, randf_range(Juice.LONG, Juice.VERYLONG))
	tween.tween_interval(hold)
	transitioned.emit()
