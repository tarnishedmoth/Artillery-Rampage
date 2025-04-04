extends Control

@onready var main_menu: VBoxContainer = %MainMenu

func _on_options_menu_closed() -> void:
	print_debug("Options menu closed -- main menu")
	main_menu.show()
