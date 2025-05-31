extends Control

@export var item_resources:ShopItemsResource
@onready var items_container:Container = %ItemsContainer

# Shop item row scenes by ItemType (Currently only weapon)
const weapon_row_scene:PackedScene = preload("res://ui/story/shop/shop_weapon_row.tscn")

class ItemPurchaseState:
	var item:ShopItemResource
	var buy:bool
	var additional_ammo:int
	
## Keyed by the scene file path of the instantiated item
var _purchase_item_state_dictionary:Dictionary[String, ItemPurchaseState] = {}
	
func _ready() -> void:
	var existing_weapons:Dictionary[String, Weapon] = {}
	var player_state:PlayerState = PlayerStateManager.player_state
	if not player_state:
		push_warning("PlayerStateManager.player_state is null, no existing weapon info")
	else:
		for weapon in player_state.weapons:
			existing_weapons[weapon.scene_file_path] = weapon
	
	var available_scrap:int = PlayerAttributes.scrap
	#var available_personnel:int = PlayerAttributes.personnel
	
	for item in item_resources.items:
		# Display a row if we have the item already and can improve the state of it or can afford to buy it
		# TODO: Sort by price
		if not item.item_scene:
			continue
		
		# Here we could choose which UI scene to instantitate by item type 
		var existing_weapon:Weapon = existing_weapons.get(item.item_scene.resource_path)
		if (existing_weapon and existing_weapon.use_ammo) or (not existing_weapon and item.unlock_cost <= available_scrap):
			var weapon_row = weapon_row_scene.instantiate()
			_purchase_item_state_dictionary[item.item_scene.resource_path] = ItemPurchaseState.new()
			
			weapon_row.shop_item = item
			items_container.add_child(weapon_row)
			
			weapon_row.on_buy_state_changed.connect(_on_weapon_buy_state_changed)
			weapon_row.on_ammo_state_changed.connect(_on_weapon_ammo_state_changed)
			
func _on_done_pressed() -> void:
	_apply_changes()
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)

func _apply_changes() -> void:
	pass
	
func _on_weapon_buy_state_changed(weapon: Weapon, buy:bool) -> void:
	print_debug("%s - Buy State changed for %s - buy=%s" % [name, weapon.display_name, str(buy)])
	
	var state: ItemPurchaseState = _purchase_item_state_dictionary[weapon.scene_file_path]
	state.buy = buy

func _on_weapon_ammo_state_changed(weapon: Weapon, new_ammo:int, old_ammo:int) -> void:
	print_debug("%s - Weapon Ammo State changed for %s - new_ammo=%d; old_ammo=%d" % [name, weapon.display_name, new_ammo, old_ammo])
	
	var state: ItemPurchaseState = _purchase_item_state_dictionary[weapon.scene_file_path]
	state.additional_ammo = new_ammo
