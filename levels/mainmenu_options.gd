extends PanelContainer

func close_options_menu() -> void:
	hide()

func _on_apply_pressed() -> void:
	print_debug("Options Apply pressed")
	close_options_menu()

func _on_cancel_pressed() -> void:
	print_debug("Options Cancel pressed")
	close_options_menu()
