extends Node

signal acquired_upgrade

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
	pass

func load_upgrades() -> void:
	pass
