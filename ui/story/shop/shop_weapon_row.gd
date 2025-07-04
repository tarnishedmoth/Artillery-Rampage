class_name ShopWeaponRow extends HBoxContainer

var shop_item:ShopItemResource

@onready var weapon_label: Label = %Weapon
@onready var cost_label: Label = %CostLabel

@onready var weapon_buy_control: WeaponBuyControl = $WeaponBuy
@onready var ammo_purchase_control: AmmoPurchaseControl = $AmmoPurchase
@onready var description_container: Container = %DescriptionContainer

var weapon:Weapon:
	get: return _existing_weapon if _existing_weapon else _new_weapon
	set(value):
		_existing_weapon = value

var _existing_weapon:Weapon
var _new_weapon:Weapon

signal on_buy_state_changed(weapon: Weapon, buy:bool)
signal on_ammo_state_changed(weapon: Weapon, new_ammo: int, old_ammo: int, cost:int)

func _exit_tree() -> void:
	if is_instance_valid(_new_weapon):
		_new_weapon.queue_free()

#region Shop Row Interface 
var buy_enabled:bool:
	get: return weapon_buy_control.enabled
	set(value):
		weapon_buy_control.enabled = value

var refill_enabled:bool:
	get: return ammo_purchase_control.enabled
	set(value):
		ammo_purchase_control.enabled = value

var refill_purchase_enabled:bool:
	get: return ammo_purchase_control.purchase_enabled
	set(value):
		ammo_purchase_control.purchase_enabled = value

func reset() -> void:
	weapon_buy_control.reset()
	ammo_purchase_control.reset()

#endregion

func _ready() -> void:
	if not shop_item:
		push_error("%s: No shop item set!" % name)
		return
	var player_state: PlayerState = PlayerStateManager.player_state
	if not player_state:
		push_error("%s: No player_state exists!" % name)
		return
	var weapon_scene: PackedScene = shop_item.item_scene
	if not weapon_scene or not weapon_scene.can_instantiate():
		push_error("%s: Invalid weapon scene specified for shop item: %s" % [name, weapon_scene])
		return
	_new_weapon = weapon_scene.instantiate() as Weapon
	if not _new_weapon:
		push_error("%s: Invalid weapon scene specified for shop item: %s" % [name, weapon_scene.resource_path])
		return
	
	# Use new weapon so it doesn't show "Modified"
	weapon_label.text = weapon.display_name
	

	# Display a tooltip containing the weapon description if available
	if weapon.description:
		description_container.tooltip_text = weapon.description
		# set mouse filter to stop to make the tooltip able to appear
		description_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	weapon_buy_control.weapon = weapon
	weapon_buy_control.player_state = player_state
	weapon_buy_control.update()
	
	if weapon_buy_control.already_owned:
		cost_label.text = "(Owned)"
	else:
		cost_label.text = ShopUtils.format_cost(shop_item.unlock_cost,shop_item.unlock_cost_type)
	
	# TODO: If we support mod purchases may need to to change this state dynamically and expose as function
	# Alternatively could swap out the child for a new instance of the weapon row so that everything is initialized properly
	if not weapon.use_ammo:
		ammo_purchase_control.display = false
	else:
		ammo_purchase_control.item = shop_item
		ammo_purchase_control.weapon = weapon
		ammo_purchase_control.initialize()
		
	_connect_signals()
	
func _connect_signals() -> void:
	if weapon_buy_control.enabled:
		weapon_buy_control.buy_button.toggled.connect(func(toggled_on:bool)->void:
			on_buy_state_changed.emit(weapon, toggled_on)
			# if toggle buy to false then reset any ammo purchased and be sure to fire signals so that resources updated appropriately
			if not toggled_on and ammo_purchase_control.display:
				ammo_purchase_control.reset(true)
		)
	
	if ammo_purchase_control.enabled:
		ammo_purchase_control.ammo_updated.connect(func(new_ammo:int, old_ammo:int, cost:int)->void:
			on_ammo_state_changed.emit(weapon, new_ammo, old_ammo, cost)
		)
