class_name ShopWeaponRow extends HBoxContainer

var shop_item:ShopItemResource

@onready var weapon_label: Label = $Weapon
@onready var weapon_buy_control: WeaponBuyControl = $WeaponBuy
@onready var ammo_purchase_control: AmmoPurchaseControl = $AmmoPurchase

var _weapon:Weapon

func _exit_tree() -> void:
	if is_instance_valid(_weapon):
		_weapon.queue_free()
		
func _ready() -> void:
	if not shop_item:
		push_error("%s: No shop item set!" % name)
		return
	var player_state := PlayerStateManager.player_state
	if not player_state:
		push_error("%s: No player_state exists!" % name)
		return
	var weapon_scene:PackedScene = shop_item.item_scene
	if not weapon_scene or not weapon_scene.can_instantiate():
		push_error("%s: Invalid weapon scene specified for shop item: %s" % [name, weapon_scene])
		return
	_weapon = weapon_scene.instantiate() as Weapon
	if not _weapon:
		push_error("%s: Invalid weapon scene specified for shop item: %s" % [name, weapon_scene.resource_path])
	
	weapon_label.text = _weapon.display_name
	
	weapon_buy_control.weapon = _weapon
	weapon_buy_control.player_state = player_state
	weapon_buy_control.update()
	
