## This script is a fix for a Godot editor bug.
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
	print_rich("[bgcolor=WHITE] - - - - [b][color=#54B0BD]Welcome to Artillery Rampage - - - - ")
	
	if Engine.is_editor_hint():
		#ResourceSaver.save(preload()) # Moved to for loop
		generate(SCRIPTS)
	

func generate(array: Array) -> void:
	for i:String in array:
		ResourceSaver.save(load(i))
