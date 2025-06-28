class_name UIUtils

static func get_health_pct_display(current_health:float, max_health:float) -> String:
	# Round pct to nearest tenth
	var pct:float = roundf(current_health / max_health * 1000.0) / 10.0
	return "%.1f%%" % pct

static func disable_all_buttons(buttons_container: Container, reenable_timeout:float = -1.0) -> void:
	var disabled_buttons:Array[Button] = []
	
	for control in buttons_container.get_children():
		var button:Button = control as Button
		if button and not button.disabled:
			button.disabled = true
			disabled_buttons.push_back(button)
	
	if reenable_timeout <= 0:
		return
		
	# If the buttons are still valid after the timeout that means something went wrong, and we didn't transition so
	# re-enable the buttons
	await buttons_container.get_tree().create_timer(reenable_timeout).timeout
	
	for button in disabled_buttons:
		if is_instance_valid(button):
			push_warning("UIUtils: Re-enabling button %s after timeout of %fs" % [button.name, reenable_timeout])
			button.disabled = false
