extends Node # Autoload

## Emitted for each upgrade whenever the player acquires a new upgrade.
## Primarily used to get a display name for UI (mod_bundle.name).
signal acquired_upgrade(mod:ModBundle)

var current_upgrades:Array[ModBundle]
var _dirty:bool

func get_current_upgrades() -> Array[ModBundle]:
	return current_upgrades

func acquire_upgrade(mod_bundle:ModBundle) -> void:
	_on_acquired_upgrade(mod_bundle)

func _on_acquired_upgrade(mod_bundle:ModBundle) -> void:
	print_debug("Acquired upgrade")
	_dirty = true

	current_upgrades.append(mod_bundle)
	acquired_upgrade.emit(mod_bundle)

#region Savable

const SAVE_STATE_KEY:StringName = &"PlayerUpgrades"

func restore_from_save_state(_save: SaveState) -> void:
	if SceneManager.play_mode != SceneManager.PlayMode.STORY:
		return

	current_upgrades.clear()

	var story_save:Dictionary = StorySaveUtils.get_story_save()
	if not story_save or not story_save.has(SAVE_STATE_KEY) or SaveStateManager.consume_state_flag(SceneManager.new_story_selected, SAVE_STATE_KEY):
		print_debug("PlayerUpgrades: New Story - clearing upgrades")
		_dirty = true
		return
	
	var upgrade_state:Dictionary = story_save[SAVE_STATE_KEY]
	var current_upgrade_data:Array[Dictionary] = upgrade_state.get("upgrades", [])

	for data in current_upgrade_data:
		var result:ModBundle = ModBundle.deserialize(data)
		if result:
			current_upgrades.push_back(result)
		else:
			push_warning("PlayerUpgrades: Save data entry deserialized to null")

	print_debug("PlayerUpgrades: Restored %d upgrades - %s" % [current_upgrade_data.size(), current_upgrade_data])


func update_save_state(_save:SaveState) -> void:
	if not _dirty or SceneManager.play_mode != SceneManager.PlayMode.STORY:
		return

	var story_save:Dictionary = StorySaveUtils.get_story_save()
	if not story_save:
		return

	var upgrade_state:Dictionary = {}
	var current_upgrade_data:Array[Dictionary] = []
	current_upgrade_data.resize(current_upgrades.size())

	for i in current_upgrades.size():
		current_upgrade_data[i] = current_upgrades[i].serialize()

	upgrade_state["upgrades"] = current_upgrade_data
	story_save[SAVE_STATE_KEY] = upgrade_state

#endregion


static func generate_random_upgrade(types:Array[ModBundle.Types], layers:int = 1, chance_bias:int = 0) -> ModBundle:
	var upgrade = ModBundle.new()

	# More than 1 layer means multiple Mods in a ModBundle. Use for 'rarity'.
	# Chance bias pushes the probability more toward buff or de-buff. Use for shop
	upgrade.randomize(types, layers, chance_bias)

	var player_state:PlayerState = PlayerStateManager.player_state
	if not player_state:
		push_error("PlayerUpgrades: No player state available to determine available inventory to apply the generate mod bundle to")
		return upgrade

	# select a random weapon to apply the upgrades to if there is a ModWeapon
	if upgrade.components_weapon_mods:
		var weapons_inventory:Array[Weapon] = player_state.weapons
		if not weapons_inventory:
			push_error("PlayerUpgrades: Player state has empty weapons!")
			return upgrade

		var selected_weapon:Weapon = weapons_inventory.pick_random()

		for weapon_mod in upgrade.components_weapon_mods:
			print_debug("PlayerUpgrades: Applying weapon mod to %s" % selected_weapon.display_name)
			weapon_mod.target_weapon_name = selected_weapon.display_name
			weapon_mod.target_weapon_scene_path = selected_weapon.scene_file_path

	# TODO: how to apply projectile mods to weapons?
	return upgrade
