class_name StoryLevel extends Resource
	
## Full path to the scene resource. Value of "Copy Path" when right clicking the scene file in the editor file system.
## e.g. "res://levels/test/environments/test_level_environment_whitecaps.tscn"
@export var scene_res_path:StringName

## Name of the level as it should appear to the player.
@export var name:StringName

## Scene file that is subclass of StoryLevelNode
@export var ui_map_node:PackedScene

## Used to replace the Icon inside the ui_map_node.
## because why have another scene for every single level?
@export var ui_map_node_texture:Texture2D

## Text to display on the map node when moving to next level
@export_group("Narrative")
@export_multiline var narratives:Array[String]

@export_group("AI")
## Override to change the AI starting weapons for this story level by difficulty
## If there is no entry for a particular difficulty then no modifications will be made
## Enums did not work as enum keys in resources so needed to change to int
@export var ai_config_by_difficulty:Dictionary[int, AIStoryConfig] = {}

@export_group("Level Modifiers")
@export var force_player_goes_first:bool = false
