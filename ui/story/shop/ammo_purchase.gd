class_name AmmoPurchaseControl extends HBoxContainer

var ammo:int

# TODO: This should be set based on weapon limits and how much can be afforded
var max_ammo:int = 99

var _increment:int

var item: ShopItemResource
var weapon: Weapon

@onready var increment_button:Button = %Increment
@onready var decrement_button:Button = %Decrement
@onready var count_label:Label = %Count
@onready var cost_label:Label = %Cost

signal ammo_updated(new_ammo:int, old_ammo:int, cost:int)

## Alternative to visible where it takes up space but isn't rendered and non-interative
var display:bool = true:
	get: return visible and display
	set(value):
		display = value
		
		# Make it effectively invisible but still take up space in layout
		modulate.a = 1.0 if value else 0.0
		
		var disable_buttons:bool = not display or not enabled
		increment_button.disabled = disable_buttons
		decrement_button.disabled = disable_buttons
	
var enabled:bool = true:
	get: return display and enabled
	set(value):
		if not display:
			return
		enabled = value
		increment_button.disabled = not enabled
		decrement_button.disabled = not enabled
		
		if not value:
			ammo = 0
			_update_labels(0)

var purchase_enabled:bool:
	get: return enabled and not increment_button.disabled
	set(value):
		if not enabled:
			return
		increment_button.disabled = not value
		
func reset() -> void:
	# Toggle so all state reset
	enabled = false
	enabled = true
	
func initialize() -> void:
	_increment = item.get_increment_for_fractional_cost()
	_update_labels(0)

func _on_increment_pressed() -> void:
	_update(_increment)

func _on_decrement_pressed() -> void:
	_update(-_increment)

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
