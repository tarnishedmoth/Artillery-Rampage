extends Node

@export var color_pulse:Color = Color.DARK_GRAY
@export var speed:float = 5.0

@onready var parent:CanvasItem = get_parent()
@onready var orig_mod:Color = parent.modulate

func _ready() -> void:
	await get_tree().create_timer(speed/2)
	var tween:Tween = parent.create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(parent, ^"modulate", color_pulse, speed/2)
	tween.tween_property(parent, ^"modulate", orig_mod, speed/2)
