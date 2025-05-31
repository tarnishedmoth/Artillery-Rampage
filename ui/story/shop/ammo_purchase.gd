class_name AmmoPurchaseControl extends HBoxContainer

var ammo:int

# TODO: This should be set based on weapon limits and how much can be afforded
var max_ammo:int = 99

var item: ShopItemResource
var weapon: Weapon

@onready var increment_button:Button = %Increment
@onready var decrement_button:Button = %Decrement
@onready var count_label:Label = %Count
@onready var cost_label:Label = %Cost

signal ammo_updated(new_ammo:int, old_ammo:int, cost:int)

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
	
func initialize() -> void:
	_update_labels(0)

func _on_increment_pressed() -> void:
	_update(1)

func _on_decrement_pressed() -> void:
	_update(-1)

func _update(delta:int) -> void:
	var previous_ammo:int = ammo
	ammo = clampi(ammo + delta, 0, max_ammo)
	
	if ammo != previous_ammo:
		var cost: int = item.get_refill_cost(ammo)
		_update_labels(cost)
		ammo_updated.emit(ammo, previous_ammo, cost)
	
func _update_labels(cost: int) -> void:
	_update_ammo_text()
	_update_cost_text(cost)
	
func _update_ammo_text() -> void:
	count_label.text = "%d" % ammo
	
func _update_cost_text(cost: int) -> void:
	cost_label.text = ShopUtils.format_cost(cost, item.refill_cost_type)
