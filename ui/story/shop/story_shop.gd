extends Control

@export var item_resources:ShopItemsResource
@export var min_remaining_scrap:int = 0
@export var min_remaining_personnel:int = 1

@onready var items_container:Container = %ItemsContainer
@onready var resources_control:ShopResourceRowControl = %ResourceRow

# Shop item row scenes by ItemType (Currently only weapon)
const weapon_row_scene:PackedScene = preload("res://ui/story/shop/shop_weapon_row.tscn")

class ItemPurchaseState:
	var item:ShopItemResource
	var existing_item: Node
	var new_item:Node
	var ui_control:Control
	var buy:bool
	var additional_ammo:int
	
	func reset() -> void:
		buy = false
		additional_ammo = 0
		ui_control.reset()
	
## Keyed by the scene file path of the instantiated item
var _purchase_item_state_dictionary:Dictionary[String, ItemPurchaseState] = {}

var pending_scrap_spend:int
var pending_personnel_spend:int
	
func _ready() -> void:
	var existing_weapons:Dictionary[String, Weapon] = {}
	var player_state:PlayerState = PlayerStateManager.player_state
	if not player_state:
		push_warning("PlayerStateManager.player_state is null, no existing weapon info")
	else:
		for weapon in player_state.weapons:
			existing_weapons[weapon.scene_file_path] = weapon
	
	_update_resources_control_state()
	
	var sorted_items: Array[ShopItemResource] = item_resources.items.duplicate()
	sorted_items.sort_custom((func(a,b)->bool: return a.unlock_cost < b.unlock_cost))
	
	for item in sorted_items:
		# Display a row if we have the item already and can improve the state of it or can afford to buy it
		if not item.item_scene:
			continue
		
		# Here we could choose which UI scene to instantitate by item type 
		var existing_weapon:Weapon = existing_weapons.get(item.item_scene.resource_path)
		if (existing_weapon and existing_weapon.use_ammo) or (not existing_weapon and can_afford_to_buy_item(item)):
			var weapon_row = weapon_row_scene.instantiate()

			var purchase_state:ItemPurchaseState = ItemPurchaseState.new()
			purchase_state.item = item
			purchase_state.existing_item = existing_weapon
			purchase_state.ui_control = weapon_row
			_purchase_item_state_dictionary[item.item_scene.resource_path] = purchase_state
			
			weapon_row.shop_item = item
			items_container.add_child(weapon_row)
			
			weapon_row.on_buy_state_changed.connect(_on_weapon_buy_state_changed)
			weapon_row.on_ammo_state_changed.connect(_on_weapon_ammo_state_changed)

func can_afford_to_buy_item(item: ShopItemResource) -> bool:
	if item.unlock_cost_type == ShopItemResource.CostType.Scrap:
		return PlayerAttributes.scrap - item.unlock_cost - pending_scrap_spend - min_remaining_scrap >= 0
	return PlayerAttributes.personnel - item.unlock_cost - pending_personnel_spend - min_remaining_personnel >= 0
				
func _on_done_pressed() -> void:
	_apply_changes()
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)

func _apply_changes() -> void:
	# Update the player state with the new weapon states
	var player_state:PlayerState = PlayerStateManager.player_state
	assert(player_state, "PlayerStateManager.player_state is null, cannot apply changes")

	for purchase_state_key in _purchase_item_state_dictionary:
		var purchase_state:ItemPurchaseState = _purchase_item_state_dictionary[purchase_state_key]
		match purchase_state.item.item_type:
			ShopItemResource.ItemType.Weapon:
				_apply_weapon(player_state, purchase_state)
			_:
				push_warning("%s: Unsupported item type %s found for purchase_state item=%s" % [name, str(purchase_state.item.item_type), purchase_state.item.resource_path])
	
func _apply_weapon(player_state: PlayerState, purchase_state: ItemPurchaseState)  -> void:
	var existing_weapon:Weapon = purchase_state.existing_item as Weapon
	if existing_weapon:
		# TODO: Take into account magazines
		existing_weapon.current_ammo += purchase_state.additional_ammo
		if purchase_state.additional_ammo > 0:
			print_debug("%s: Purchased %d ammo for weapon %s" % [name, purchase_state.additional_ammo, existing_weapon.display_name])
	elif purchase_state.buy:
		assert(purchase_state.new_item)

		# Need to duplicate as the reference above is owned by the UI element and will be freed when this node exits
		player_state.weapons.push_back(purchase_state.new_item.duplicate())
		
		print_debug("%s: Purchased new weapon - %s" % [name, purchase_state.new_item.display_name])

func _on_weapon_buy_state_changed(weapon: Weapon, buy:bool) -> void:
	print_debug("%s - Buy State changed for %s - buy=%s" % [name, weapon.display_name, str(buy)])
	
	var state: ItemPurchaseState = _purchase_item_state_dictionary[weapon.scene_file_path]
	state.buy = buy
	state.new_item = weapon
		
	var delta:int = state.item.unlock_cost if buy else -state.item.unlock_cost
	if state.item.unlock_cost_type == ShopItemResource.CostType.Scrap:
		pending_scrap_spend = maxi(0, pending_scrap_spend + delta)
	else:
		pending_personnel_spend = maxi(0, pending_personnel_spend + delta)
		
	_update_resources_control_state()
	_update_row_states()

func _update_resources_control_state() -> void:
	resources_control.update_values(
		PlayerAttributes.scrap - pending_scrap_spend,
		PlayerAttributes.personnel - pending_personnel_spend
	)

func _on_weapon_ammo_state_changed(weapon: Weapon, new_ammo:int, old_ammo:int) -> void:
	print_debug("%s - Weapon Ammo State changed for %s - new_ammo=%d; old_ammo=%d" % [name, weapon.display_name, new_ammo, old_ammo])
	
	var state: ItemPurchaseState = _purchase_item_state_dictionary[weapon.scene_file_path]
	# TODO: Scrap cost implementation based on purchased ammo
	# TODO: Update pending spend and enabled state of those that can still be afforded

	state.additional_ammo = new_ammo

func _update_row_states() -> void:
	for purchase_state_key in _purchase_item_state_dictionary:
		var purchase_state:ItemPurchaseState = _purchase_item_state_dictionary[purchase_state_key]
		# If not yet buying make sure still have enough
		# TODO: Account for ammo cost
		if purchase_state.buy or purchase_state.existing_item:
			continue
		
		var item: ShopItemResource = purchase_state.item
		purchase_state.ui_control.enabled = can_afford_to_buy_item(item)


func _on_reset_pressed() -> void:
	pending_personnel_spend = 0
	pending_scrap_spend = 0
	
	_update_resources_control_state()
	
	# Reset the purchase state and then reset the enabled status
	for purchase_state in _purchase_item_state_dictionary.values():
		purchase_state.reset()
		
	_update_row_states()
