## Stores global game state that can extend beyond a given level
## To use tag a class with group "Savable"
## When instantiating that class in group 
## 1) define a function "func restore_from_save_state(save: SaveState) -> void" to restore node from save state and it will be called when loading save state
## You need to handle if this is called before or after _ready. Currently it will be called after _ready based on SceneManager implementation
## 2) Define a function with signature "func update_save_state(game_state:SaveState) -> void" and it will be called when the save system is invoked
## and allow class to read into dictionary for its saved state and downcast to resource derived type it stored
## It will set/update any keys in this dictionary with its resource derived state
## The GameState can then be saved to a file using ResourceSaver and loaded using ResourceLoader
class_name SaveState extends Resource

# TODO: Retrofit the adhoc system done for TankController and Tank to use this system
# Can attach the game state to this
@export
var state: Dictionary[StringName, Resource] = {}
