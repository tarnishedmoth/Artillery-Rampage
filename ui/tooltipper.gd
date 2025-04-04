extends Control

func _ready() -> void:
	GameEvents.user_options_changed.connect(_on_user_options_changed)
	if UserOptions.show_tooltips:
		show()
	else:
		hide()

func _on_user_options_changed() -> void:
	if UserOptions.show_tooltips:
		if not visible: show()
	else:
		if visible: hide()
