## This script is a fix for a Godot editor bug.
##
## Godot automatically generates documentation pages for GDScript files, but they
## are only made on-demand, so each time you launch the editor you would need to
## load and modify the script to access its documentation in the editor search help (F1).
##
## This workaround just forces the editor to do this for you.
## But it doesn't fix it immediately.
##
## There is a second bug with Godot 4 where @tool scripts will not run the first time the project
## is loaded in the editor. After first launching the editor, you have to go to the menu bar and
## navigate to Project->Reload Current Project. Once the project has loaded, this script will run.
##
## https://github.com/godotengine/godot/issues/72406 # Documentation generation bug
## https://github.com/godotengine/godot/issues/66381 # @tool scripts won't run until reload.
##

@tool
extends EditorPlugin

const SCRIPTS = [
	"res://weapons/weapon.gd",
	"res://weapons/mod_weapon.gd",
	"res://items/weapon_projectiles/mod_projectile.gd",
	"res://items/weapon_projectiles/weapon_projectile.gd",
	
	"res://tank/tank.gd",
	"res://controller/tank_controller.gd",
	"res://controller/player/player.gd",
	"res://controller/ai/ai_tank.gd",
]

func _ready() -> void:
	print_rich("[bgcolor=WHITE] - - - - [b][color=#54B0BD]Welcome, HomeTeam Game Dev - - - - ")
	
	if Engine.is_editor_hint():
		#ResourceSaver.save(preload()) # Moved to for loop
		generate(SCRIPTS)
	

func generate(array: Array) -> void:
	for i:String in array:
		ResourceSaver.save(load(i))
