class_name UIUtils

static func get_health_pct_display(current_health:float, max_health:float) -> String:
	# Round pct to nearest tenth
	var pct:float = roundf(current_health / max_health * 1000.0) / 10.0
	return "%.1f%%" % pct
