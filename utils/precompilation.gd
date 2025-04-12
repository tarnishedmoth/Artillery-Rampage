## Avoid hitches and skips by previewing all of the game entities before loading the game.
## Does NOT recursively load subdirectories

extends Node2D

@export_dir var scene_folders:Array[String]

func _ready() -> void:
	
	# Get all the scenes we want to preview
	var scene_paths = find_scene_files(scene_folders)

func find_scene_files(folders:Array[String]) -> Array[String]:
	var files:Array
	
	for folder in folders:
		for file in folder:
			if file.ends_with(".tscn"):
				var path = folder + "/" + file
				files.append(path)
			
	return files
