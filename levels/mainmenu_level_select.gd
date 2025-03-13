extends PanelContainer

@export_dir var levels_folders_paths: Array[String]
@onready var menu_levels_list: VBoxContainer = %Buttons
@onready var main_menu: VBoxContainer = %MainMenu

var selected_level:String
var scan_all_levels:bool

#region Inner Classes
class LabelDirectory extends Label:
	func _init(display_text:String) -> void:
		text = display_text

class ButtonLevel extends Button:
	var level_file_path := String()
	var on_pressed_callable:Callable
	func _init(full_file_path:String, display_text:String, press_call:Callable) -> void:
		level_file_path = full_file_path
		text = display_text
		on_pressed_callable = press_call
		
	func _ready() -> void:
		pressed.connect(on_pressed_callable.bind(self))
#endregion

func _ready() -> void:
	scan_all_levels = true if OS.is_debug_build() else false
	
	visibility_changed.connect(_on_visibility_changed)
	
func refresh_list(path) -> void:
	# for scene in levels folder and subfolders make a new button that triggers the func for loading its level
	if scan_all_levels: # Debug (all levels)
		print_debug("Debug build detected: scanning all levels")
		
		var items:Array
		
		# Get the filenames & directory names we need
		for directory in levels_folders_paths:
			items.append(directory)
			var filepaths = DirAccess.get_files_at(directory)
			for filepath in filepaths:
				if filepath.ends_with("tscn"):
					items.append(filepath)
		
		# Generate the menu
		var current_directory:String
		for item:String in items:
			if not item.ends_with("tscn"):
				# Directory
				current_directory = item
				var entry := LabelDirectory.new(str(item,":"))
				menu_levels_list.add_child(entry)
			else:
				# Level
				var entry := ButtonLevel.new(
					str(current_directory,"/",item), # Full file path
					item.trim_suffix(".tscn"), # Display text
					_on_level_selected) # Callable
				menu_levels_list.add_child(entry)
	else:
		pass # Normal gameplay
	
func load_level(level:String) -> void:
	SceneManager.switch_scene_file(level)
	
	
func _on_visibility_changed() -> void:
	if visible: refresh_list("res://levels/")
	
func _on_level_selected(button:ButtonLevel) -> void: #Expects file path
	selected_level = button.level_file_path
	print_debug("Selected", selected_level)

func _on_cancel_pressed() -> void:
	hide()
	main_menu.show()

func _on_apply_pressed() -> void:
	if not selected_level.is_empty():
		load_level(selected_level)
