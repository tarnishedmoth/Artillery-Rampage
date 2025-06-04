class_name ButtonUpgradeSelection extends Button

signal selected(button:ButtonUpgradeSelection)

@export var mod_bundle:ModBundle

## If randomize chosen then a random mod is generated per the type specification
@export var randomize_mod:bool = false
@export var random_mod_types:Array[ModBundle.Types] = [ModBundle.Types.WEAPON]

func _init() -> void:
	pressed.connect(_on_pressed)

func get_mod_bundle() -> ModBundle:
	if randomize_mod:
		return PlayerUpgrades.generate_random_upgrade(random_mod_types)
	return mod_bundle

func _on_pressed() -> void:
	selected.emit(self)
