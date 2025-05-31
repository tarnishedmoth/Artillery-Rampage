class_name AmmoPurchaseControl extends HBoxContainer

var ammo:int 

@onready var increment_button:Button = %Increment
@onready var decrement_button:Button = %Decrement
@onready var count_label:Label = %Count

signal ammo_updated(new_ammo:int, old_ammo:int)

var enabled:bool:
	get: return visible
	
func _ready() -> void:
	_update_ammo_text()

func _on_increment_pressed() -> void:
	# TODO: Should probably set a maximum
	var previous_ammo:int = ammo
	ammo += 1
	
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
