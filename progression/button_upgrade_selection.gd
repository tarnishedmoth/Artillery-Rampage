class_name ButtonUpgradeSelection extends Button

signal selected(button:ButtonUpgradeSelection)

@export var mod_bundle:ModBundle

func _init() -> void:
	pressed.connect(_on_pressed)

func get_mod_bundle() -> ModBundle:
	return mod_bundle

func _on_pressed() -> void:
	selected.emit(self)
