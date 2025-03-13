extends PanelContainer

@export var levels_list:Control
@export var level_template_button:Button

@export var scan_all_levels:bool = false

var selected_level:String

func _ready() -> void:
	if OS.is_debug_build():
		scan_all_levels = true
	
	level_template_button.hide()
	visibility_changed.connect(_on_visibility_changed)
	
func refresh_list(path) -> void:
	# for scene in levels folder and subfolders make a new button that triggers the func for loading its level
	if scan_all_levels: # Debug (all levels)
		pass
	else:
		pass # Normal gameplay
	
func load_level(level:String) -> void:
	SceneManager.switch_scene_file(level )
	
func _on_visibility_changed() -> void:
	if visible: refresh_list("res://levels/")
	
func _on_level_selected(scene) -> void: #Expects file path
	pass # Wait for Apply button

func _on_cancel_pressed() -> void:
	hide()

func _on_apply_pressed() -> void:
	if selected_level == null:
		_on_cancel_pressed()
	else:
		load_level(selected_level)
