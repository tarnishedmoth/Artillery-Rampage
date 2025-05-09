class_name PopupNotification extends Control

signal completed_lifetime(popup: PopupNotification)

const HUD_POPUP_NOTIFICATION = preload("res://ui/hud_popup_notification.tscn")

const Contexts = {
	"EMP_DISABLED": "Disabled!",
}

const PulsePresets = {
	"One": [2.0],
	"Two": [0.75, 1.0],
	"Three": [0.9, 0.9, 1.3],
}

## Each item is one pulse with a duration of time in seconds.
@export var pulses: Array[float] = [
	1.0,
	1.0,
	1.5,
]
@export var color: Color = Color.WHITE
@export var lifetime:float = 5.5 ## Above 0.0 will destroy after this time in seconds.

@export var message:String

var actual_pulses: Array # Something about instantiating and export variables don't jive

@onready var label: Label = %Label

func _ready() -> void:
	if pulses:
		if actual_pulses.is_empty():
			actual_pulses.append_array(pulses)
	
	modulate = Color.TRANSPARENT
	
	label.text = message
	
	if lifetime > 0.0:
		_destroy_after_lifetime()
	animate()
	
func animate() -> void:
	var tween = create_tween()
	
	var index = 0
	for pulse in actual_pulses:
		tween.tween_property(self, "modulate", color, actual_pulses[pulse]/2)
		if index + 1 < actual_pulses.size():
			tween.tween_property(self, "modulate", Color.TRANSPARENT, actual_pulses[pulse]/2)
		index += 1

func fade_out(duration:float) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, duration)
	await tween.finished
	#print("Cleared popup")
	completed_lifetime.emit(self)
	queue_free()
	
func _destroy_after_lifetime() -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_on_lifetime_timer_timeout)
	timer.start(lifetime)
	
func _on_lifetime_timer_timeout() -> void:
	fade_out(0.9)

static func constructor(_message:String, pulse_array:Array = PulsePresets.Three)-> PopupNotification:
	var obj = HUD_POPUP_NOTIFICATION.instantiate()
	obj.message = _message
	obj.actual_pulses = pulse_array
	return obj
