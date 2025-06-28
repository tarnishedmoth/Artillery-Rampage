class_name UIUtils

static func get_health_pct_display(current_health:float, max_health:float) -> String:
	# Round pct to nearest tenth
	var pct:float = roundf(current_health / max_health * 1000.0) / 10.0
	return "%.1f%%" % pct

static func disable_all_buttons(buttons_container: Container) -> void:
	for control in buttons_container.get_children():
		var button:Button = control as Button
		if button:
			button.disabled = true
