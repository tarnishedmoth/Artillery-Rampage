class_name ApplyTypewriterEffect extends Node

@export var apply_to:Node ## The node to apply this effect to. If empty, the parent is used.
@export var connect_to_events:bool = true ## Will react to visibility changes to the [member apply_to] node.

var effect:TypewriterEffect.TypewriterTextRevealer
var cached_text:String

func _ready() -> void:
	if not apply_to: apply_to = get_parent()

	if connect_to_events:
		if apply_to is CanvasItem:
			apply_to.visibility_changed.connect(_on_visibility_changed)

func run() -> void:
	stop()
	TypewriterEffect.apply_to(apply_to)

func stop() -> void: if effect: effect.kill()

func _on_visibility_changed() -> void:
	if apply_to.visible: run()
	else: stop()
