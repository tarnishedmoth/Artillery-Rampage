class_name ToastNotification extends CanvasLayer

@onready var label:Label = $Label
@onready var animation_player:AnimationPlayer = $AnimationPlayer

@export
var message:String = "Simultaneous Fire!"

func _ready() -> void:
	label.text = message
	
	print_debug("%s: Playing toast animation with %s" % [name, label.text])
	animation_player.play(&"toast_fade")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	print_debug("%s: Animation finished - %s" % [name, anim_name])
	queue_free()
