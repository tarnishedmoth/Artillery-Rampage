extends Control

@export var item_resources:ShopItemsResource
@onready var items_container:Container = %ItemsContainer

const weapon_row_scene:PackedScene = preload("res://ui/story/shop/shop_weapon_row.tscn")

func _ready() -> void:
	var existing_weapons:Dictionary[String, Weapon] = {}
	var player_state:PlayerState = PlayerStateManager.player_state
	if not player_state:
		push_warning("PlayerStateManager.player_state is null, no existing weapon info")
	else:
		for weapon in player_state.weapons:
			existing_weapons[weapon.scene_file_path] = weapon
	
	var available_scrap:int = PlayerAttributes.scrap
	var available_personnel:int = PlayerAttributes.personnel
	
	for item in item_resources.items:
		# TODO: Should have an ItemType enum to differentiate between weapon and other items
		# Display a row if we have the item already or can afford to buy it
		# TODO: Sort by price
		if item.item_scene and (item.item_scene.resource_path in existing_weapons or item.unlock_cost <= available_scrap):
			var weapon_row = weapon_row_scene.instantiate()
			weapon_row.shop_item = item
			items_container.add_child(weapon_row)
func _on_done_pressed() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap)
