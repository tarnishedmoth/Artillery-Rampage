extends Control

func _on_button_upgrade_a_selected(button: ButtonUpgradeSelection) -> void:
	PlayerUpgrades.acquire_upgrade(button.get_mod_bundle())


func _on_continue_button_pressed() -> void:
	SceneManager.next_level()
