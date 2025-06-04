extends Control

@export var upgrade_buttons_container:Container

@onready var continue_button:Button = %ContinueButton

var _upgrade_buttons: Array[Button] 

func _ready() -> void:
	if not upgrade_buttons_container:
		push_error("%s: buttons_container not selected in inspector" % name)
		return
	
	for control in upgrade_buttons_container.get_children():
		if control is Button:
			_upgrade_buttons.push_back(control)

func _on_button_upgrade_a_selected(button: ButtonUpgradeSelection) -> void:
	_acquire_mod(button)

func _on_button_upgrade_random_selected(button: ButtonUpgradeSelection) -> void:
	_acquire_mod(button)
	
func _on_continue_button_pressed() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryShop)

func _acquire_mod(button: ButtonUpgradeSelection) -> void:
	PlayerUpgrades.acquire_upgrade(button.get_mod_bundle())
	# Disable all buttons after selecting and continue must be pressed
	for upgrade_button in _upgrade_buttons:
		upgrade_button.disabled = true
	continue_button.disabled = false
