class_name WeaponBuyControl extends VBoxContainer

@onready var buy_button:Button = %BuyButton
@onready var current_ammo:Label = %CurrentAmmo

var weapon:Weapon
var player_state:PlayerState

func update() -> void:
	# Can only buy if don't already have
	var owned_index:int = player_state.weapons.find_custom(func(w): return w.scene_file_path == weapon.scene_file_path)
	
	buy_button.disabled = owned_index != -1
	# TODO: Doesn't account for magazines - maybe need a total_ammo derived property on the weapon for this
	current_ammo.text = "%d" % player_state.weapons[owned_index].current_ammo if owned_index != -1 else "%d" % weapon.current_ammo
