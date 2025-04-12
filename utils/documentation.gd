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

func _ready() -> void:
	#ResourceSaver.save(preload())
	
	ResourceSaver.save(preload("res://weapons/weapon.gd"))
	ResourceSaver.save(preload("res://weapons/mod_weapon.gd"))
	ResourceSaver.save(preload("res://items/weapon_projectiles/mod_projectile.gd"))
	ResourceSaver.save(preload("res://items/weapon_projectiles/weapon_projectile.gd"))
	
	ResourceSaver.save(preload("res://tank/tank.gd"))
	ResourceSaver.save(preload("res://controller/tank_controller.gd"))
	ResourceSaver.save(preload("res://controller/player/player.gd"))
	ResourceSaver.save(preload("res://controller/ai/ai_tank.gd"))
	
	#ResourceSaver.save(preload())
