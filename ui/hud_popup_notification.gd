class_name PopupNotification extends Control

const HUD_POPUP_NOTIFICATION = preload("res://ui/hud_popup_notification.tscn")

const Contexts = {
	"EMP_DISABLED": "Disabled!",
}

## Each item is one pulse with a duration of time in seconds.
@export var pulses: Array[float] = [
	1.0,
	1.0,
	1.5,
]
@export var color: Color = Color.WHITE
@export var lifetime:float = 7.0 ## Above 0.0 will destroy after this time in seconds.

@export var message:String

@onready var label: Label = %Label

func _ready() -> void:
	modulate = Color.TRANSPARENT
	
	label.text = message
	
	if lifetime > 0.0:
		_destroy_after_lifetime()
	animate()
	
func animate() -> void:
	var tween = create_tween()
	
	for pulse in pulses:
		tween.tween_property(self, "modulate", color, pulses[pulse]/2)
		if pulse + 1 < pulses.size():
			tween.tween_property(self, "modulate", Color.TRANSPARENT, pulses[pulse]/2)
			
func _destroy_after_lifetime() -> void:
	var timer = Timer.new()
	timer.timeout.connect(_on_lifetime_timer_timeout)
	timer.start(lifetime)
	
func _on_lifetime_timer_timeout() -> void:
	queue_free()

static func constructor(message: String)-> PopupNotification:
	var obj = HUD_POPUP_NOTIFICATION.instantiate()
	obj.message = message
	return obj
