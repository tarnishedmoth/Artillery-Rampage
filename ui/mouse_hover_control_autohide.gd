extends Node

@export var unhide_delay:float = Juice.SMOOTH
var parent:
	get:
		return get_parent()

var tween:Tween
var _orig_modulate:Color

func _ready() -> void:
	if parent is Control:
		parent.mouse_entered.connect(_on_mouse_entered)
		parent.mouse_exited.connect(_on_mouse_exited)
	else:
		push_error("Mouse Hover Control Autohide must be a child of a Control node!")

func _on_mouse_entered() -> void:
	if tween:
		if tween.is_running():
			tween.kill()
	tween = Juice.fade_out(parent, Juice.SNAP, parent.modulate * Color.TRANSPARENT)

func _on_mouse_exited() -> void:
	if tween:
		if tween.is_running():
			tween.kill()
	tween = create_tween()
	tween.tween_interval(unhide_delay)
	await tween.finished
	tween = Juice.fade_in(parent, Juice.SMOOTH, parent.modulate)
