class_name AmmoPurchaseControl extends HBoxContainer

var ammo:int

# TODO: This should be set based on weapon limits and how much can be afforded
var max_ammo:int = 99

@onready var increment_button:Button = %Increment
@onready var decrement_button:Button = %Decrement
@onready var count_label:Label = %Count

signal ammo_updated(new_ammo:int, old_ammo:int)

var _buttons_enabled:bool = true

var enabled:bool:
	get: return visible and _buttons_enabled
	set(value):
		if not visible:
			return
		_buttons_enabled = value
		increment_button.disabled = not _buttons_enabled
		decrement_button.disabled = not _buttons_enabled
		
		if not value:
			ammo = 0
			_update_ammo_text()

func reset() -> void:
	# Toggle so all state reset
	enabled = false
	enabled = true
	
func _ready() -> void:
	_update_ammo_text()

func _on_increment_pressed() -> void:
	var previous_ammo:int = ammo
	ammo = mini(ammo + 1, max_ammo)
	
	if ammo > previous_ammo:
		_update_ammo_text()
		ammo_updated.emit(ammo, previous_ammo)

func _on_decrement_pressed() -> void:
	var previous_ammo:int = ammo
	ammo = maxi(ammo - 1, 0)
	
	if ammo < previous_ammo:
		_update_ammo_text()
		ammo_updated.emit(ammo, previous_ammo)

func _update_ammo_text() -> void:
	count_label.text = "%d" % ammo
