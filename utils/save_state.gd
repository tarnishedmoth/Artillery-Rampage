## Stores global game state that can extend beyond a given level
## To use tag a class with group "Savable"
## When instantiating that class in group 
## 1) define a function "func restore_from_save_state(save: SaveState) -> void" to restore node from save state and it will be called when loading save state
## You need to handle if this is called before or after _ready. Currently it will be called after _ready based on SceneManager implementation
## 2) Define a function with signature "func update_save_state(game_state:SaveState) -> void" and it will be called when the save system is invoked
## and allow class to read into dictionary for its saved state and downcast to resource derived type it stored
## It will set/update any keys in this dictionary with its resource derived state
class_name SaveState

# TODO: Retrofit the adhoc system done for TankController and Tank to use this system
# Can attach the game state to this
var state: Dictionary[StringName, Dictionary] = {}

static func safe_load_scene(scene_file:String) -> Node:
	if not scene_file:
		return null
	# This technique is used by https://github.com/derkork/godot-safe-resource-loader/blob/29e27fb432ef6e8db3c81b1c0d29ed53cd75f70c/addons/safe_resource_loader/safe_resource_loader.gd#L18
	# Assumes that the file system in res:// is truly read-only
	if not scene_file.begins_with("res://"):
		push_warning("Attempted to load non-packaged scene_file=%s" % scene_file)
		return null
	var scene:PackedScene = load(scene_file) as PackedScene
	if not scene:
		push_warning("scene_file=%s is not a packed scene" % [scene_file])
		return null
		
	return scene.instantiate()
