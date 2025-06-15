class_name WeaponBuyControl extends VBoxContainer

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

	# TODO: Doesn't account for magazines - maybe need a total_ammo derived property on the weapon for this
	if weapon.use_ammo:
		current_ammo.text = "%d" % owned_weapon.current_ammo if already_owned else "%d" % weapon.current_ammo
	else:
		current_ammo.text = "N/A"
