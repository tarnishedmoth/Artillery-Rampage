extends Node # Autoload

## Emitted for each upgrade whenever the player acquires a new upgrade.
## Primarily used to get a display name for UI (mod_bundle.name).
signal acquired_upgrade(mod:ModBundle)

var current_upgrades:Array[ModBundle]

func get_current_upgrades() -> Array[ModBundle]:
	return current_upgrades

func acquire_upgrade(mod_bundle:ModBundle) -> void:
	_on_acquired_upgrade(mod_bundle)

func _on_acquired_upgrade(mod_bundle:ModBundle) -> void:
	print_debug("Acquired upgrade")
	current_upgrades.append(mod_bundle)
	acquired_upgrade.emit(mod_bundle)
	
#func _on_changed_upgrades() -> void:
	#pass

func save_upgrades() -> void:
	#TODO?
	pass

func load_upgrades() -> void:
	#TODO?
	pass


static func generate_random_upgrade(types:Array[ModBundle.Types], layers:int = 1) -> ModBundle:
	var upgrade = ModBundle.new()
	upgrade.randomize(types, layers) # More than 1 layer means multiple Mods in a ModBundle. Use for 'rarity'.

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

	# TODO: how to apply projectile mods to weapons?
	return upgrade
