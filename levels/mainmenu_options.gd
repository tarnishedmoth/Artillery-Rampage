extends PanelContainer

@onready var main_menu: VBoxContainer = %MainMenu

func close_options_menu() -> void:
	hide()
	main_menu.show()

func _on_apply_pressed() -> void:
	print_debug("Options Apply pressed")
	close_options_menu()

func _on_cancel_pressed() -> void:
	print_debug("Options Cancel pressed")
	close_options_menu()
