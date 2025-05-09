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
	acquired_upgrade.emit()
	
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
	return upgrade
