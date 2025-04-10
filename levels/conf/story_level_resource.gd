class_name StoryLevel extends Resource
	
## Full path to the scene resource. Value of "Copy Path" when right clicking the scene file in the editor file system.
## e.g. "res://levels/test/environments/test_level_environment_whitecaps.tscn"
@export var scene_res_path:StringName

## Name of the level as it should appear to the player.
@export  var name:StringName

## Scene file that is subclass of StoryLevelNode
@export  var ui_map_node:PackedScene

## Text to display on the map node when moving to next level
@export_group("Narrative")
@export_multiline var narratives:Array[String]
