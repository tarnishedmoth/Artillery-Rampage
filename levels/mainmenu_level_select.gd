extends PanelContainer

@export var levels_always_selectable: Array[PackedScene] ## These levels are immediately & always available to select.
@export_dir var levels_folders_paths: Array[String] ## This functionality is only available in debug builds.
@onready var menu_levels_list: VBoxContainer = %Buttons
@onready var main_menu: VBoxContainer = %MainMenu

var selected_level
var scan_all_levels:bool

#region Inner Classes
class LabelDirectory extends Label:
	func _init(display_text:String) -> void:
		text = display_text
		
class ButtonLevel extends Button:
	var on_pressed_callable:Callable
	func _init(display_text:String, press_call:Callable) -> void:
		text = display_text
		on_pressed_callable = press_call
		
	func _ready() -> void:
		pressed.connect(on_pressed_callable.bind(self)) # Assigns callable to be called when button is pressed

## Filepath based scenes, for debug mode only
class ButtonLevelFile extends ButtonLevel:
	var file_path := String()
		
	func _init(full_file_path:String, display_text:String, press_call:Callable) -> void:
		file_path = full_file_path
		super(display_text, press_call)
		
## Packed scenes
class ButtonLevelPackedScene extends ButtonLevel:
	var scene: PackedScene
	
	func _init(packed_scene: PackedScene, display_text:String, press_call:Callable) -> void:
		scene = packed_scene
		super(display_text, press_call)
#endregion

func _ready() -> void:
	scan_all_levels = true if OS.is_debug_build() else false
	
	visibility_changed.connect(_on_visibility_changed)
	
func refresh_list(path) -> void:
	var items: Array
	
	# Add always available levels
	if not levels_always_selectable.is_empty():
		if scan_all_levels: add_menu_item("Always Selectable", _on_level_selected)
		for level in levels_always_selectable:
			add_menu_item(level, _on_level_selected)
	
	# Debug builds only
	# for scene in levels folder and subfolders make a new button that triggers the func for loading its level
	if scan_all_levels:
		var pathstrings: Array[String]
		print_debug("Debug build detected: scanning all levels")
		add_menu_item() # Empty spacer
		add_menu_item("DEBUG", _on_level_selected)
		
		# Get the filenames & directory names we need
		for directory in levels_folders_paths:
			pathstrings.append_array(recursive_files_and_folders(directory))
		
		# Generate the menu
		var current_directory:String
		for pathstring:String in pathstrings:
			if not pathstring.ends_with("tscn"):
				# Directory
				current_directory = pathstring
				add_menu_item(current_directory, _on_level_selected)
			else:
				# Level
				var composite_path = current_directory+"/"+pathstring
				add_menu_item(composite_path, _on_level_selected)
		
func recursive_files_and_folders(directory) -> Array:
	var items: Array
	print(directory)
	items.append(directory)
	var filepaths = DirAccess.get_files_at(directory)
	for filepath in filepaths:
		print(filepath)
		if filepath.ends_with("tscn"): # PackedScene
			items.append(filepath)
			
	var subdirectories = DirAccess.get_directories_at(directory)
	if not subdirectories.is_empty():
		for sub in subdirectories:
			items.append_array(recursive_files_and_folders(directory+"/"+sub))
	return items
	
func add_menu_item(item = null, press_call:Callable = _on_level_selected) -> void:
	var entry
	if item == null:
		entry = LabelDirectory.new("")
	elif item is PackedScene:
		entry = ButtonLevelPackedScene.new(
			item,
			"Level",
			_on_level_selected)
	elif item is String:
		if not item.ends_with("tscn"):
			# Directory
			entry = LabelDirectory.new(str(item,":"))
		else:
			# Level
			entry = ButtonLevelFile.new(
				str(item), # Full file path
				item.trim_suffix(".tscn"), # Display text
				_on_level_selected) # Callable
	
	menu_levels_list.add_child(entry)
	
func load_level(level) -> void:
	if selected_level is ButtonLevelFile:
		SceneManager.switch_scene_file(level.file_path)
	elif selected_level is ButtonLevelPackedScene:
		SceneManager.switch_scene(level.scene)
	
func _on_visibility_changed() -> void:
	if visible: refresh_list("res://levels/")
	
func _on_level_selected(button:ButtonLevel) -> void: #Expects file path
	selected_level = button
	print_debug("Selected", selected_level)

func _on_cancel_pressed() -> void:
	hide()
	main_menu.show()

func _on_apply_pressed() -> void:
	if selected_level:
		load_level(selected_level)
