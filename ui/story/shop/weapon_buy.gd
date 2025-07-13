class_name WeaponBuyControl extends VBoxContainer

@export var buy_button_not_owned_text:String = "Not Owned"
@export var buy_button_toggled_text:String = "Pending Sale"
@export var buy_button_owned_text:String = "Owned"

@onready var buy_button:Button = %BuyButton
@onready var current_ammo:Label = %CurrentAmmo

var item: ShopItemResource
var weapon:Weapon
var player_state:PlayerState
var already_owned:bool

var enabled:bool:
	get: return not buy_button.disabled
	set(value):
		# Cannot change state if already owned as cannot buy
		if already_owned:
			return
		else:
			buy_button.disabled = not value
			
func _ready() -> void:
	set_buy_button_text_by_state()
		
func reset() -> void:
	enabled = true
	buy_button.set_pressed_no_signal(false)
		
func update() -> void:
	# Can only buy if don't already have
	# TODO: Code duplication from story_shop.gd
	var owned_index:int = player_state.weapons.find_custom(func(w): return w.scene_file_path == weapon.scene_file_path)
	var owned_weapon:Weapon
	if owned_index != -1:
		owned_weapon = player_state.weapons[owned_index]
	else:
		owned_weapon = player_state.get_empty_weapon_if_unlocked(weapon.scene_file_path)
	already_owned = owned_weapon != null
	
	buy_button.disabled = already_owned
	set_buy_button_text_by_state()

	if weapon.use_ammo:
		current_ammo.text = str(_get_total_current_ammo(owned_weapon if already_owned else weapon))
	else:
		# Infinity Unicode symbol
		current_ammo.text = char(8734)
		
func _get_total_current_ammo(in_weapon: Weapon) -> int:
	var total_ammo:int = in_weapon.current_ammo
	if in_weapon.use_magazines and in_weapon.magazines > 0:
		var additional_magazine_count:int = in_weapon.magazines - 1 if in_weapon.current_ammo == in_weapon.magazine_capacity else in_weapon.magazines
		total_ammo += additional_magazine_count * in_weapon.magazine_capacity
	return total_ammo

func set_buy_button_text_by_state() -> void:
	if buy_button.disabled:
		buy_button.text = buy_button_owned_text
		current_ammo.show()
	else:
		buy_button.text = buy_button_not_owned_text
		current_ammo.hide()

func _on_buy_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		buy_button.text = buy_button_toggled_text
		current_ammo.show()
	else:
		buy_button.text = buy_button_not_owned_text
		current_ammo.hide()
