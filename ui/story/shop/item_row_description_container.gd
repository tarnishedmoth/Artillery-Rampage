extends VBoxContainer

func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip = Label.new()
	tooltip.text = for_text
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip.custom_minimum_size = Vector2(250, 0)
	tooltip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip.size_flags_vertical = Control.SIZE_EXPAND_FILL

	return tooltip
