## Avoid hitches and skips by previewing all of the game entities before loading the game.
## Will load and instantiate every tscn in each directory added.
## [i]Does not[/i] recursively load subdirectories.
extends Node2D

signal progress_changed(progress:float)
signal entity_count_changed(count:int)
signal completed

@export_dir var scene_folders:Array[String] ## Loads all tscn files in these directories
@export var batch_size:int = 2 ## Scenes to instantiate at once

var progress:float # 0.0 to 1.0
var total_scenes:int
var remainder:int # The number of scenes left to spawn.

#region Public
func run() -> void:
	SceneManager.is_precompiler_running = true
	
	# Probably need to be on screen to get the benefit
	if not visible: show()
	await get_tree().process_frame
	# Run logic
	#if not OS.is_debug_build():
	await precompile_all_configured_scenes()
	
	# TODO Reset the game state in case anything was altered
	SceneManager.is_precompiler_running = false
	completed.emit()

## The main method
func precompile_all_configured_scenes() -> void:
	const print_colors:String = "[bgcolor=grey][color=black]"
	
	## Get full resource paths through ResourceLoader
	var scene_paths = find_scene_files(scene_folders, true)
	
	total_scenes = scene_paths.size() # For the visual elements
	entity_count_changed.emit(total_scenes)
	
	remainder = total_scenes
	
	await get_tree().process_frame
	
	## Load the PackedScenes from the ResourceLoader into batches -- (Pre-instancing)
	var _batch:Array[PackedScene] ## Holds scenes in the iterator to copy into batches
	var batches:Array[Array] ## Holds batches of scenes to be spawned
	var index := 0
	for path in scene_paths:
		# Get the scene
		var scene = ResourceLoader.load(path,"PackedScene")
		print_rich(print_colors,"Loaded ", path)
		_batch.append(scene)
		if index % batch_size == 0:
			# Copy this batch off and start over
			batches.append(_batch.duplicate())
			_batch.clear()
		index += 1
	if not _batch.is_empty(): batches.append(_batch) # Add final unfilled batch
	print_rich(print_colors,"Loaded ", total_scenes, " scenes.")
	
	await get_tree().process_frame
	## Instancing
	for batch:Array in batches:
		await spawn_batch(%InstancesContainer, batch)
		await get_tree().process_frame
		
		## Finished this batch
		remainder -= batch.size()
		print_rich(print_colors, remainder, " scenes remaining.")
		#var _progress:float = 100.0-(float(remainder)/float(total_scenes) * 100)
		var _progress:float = 1.0-(float(remainder)/float(total_scenes))
		progress = _progress
		progress_changed.emit(_progress)
	
	## Completed precompiling
	await get_tree().physics_frame
	return

func spawn_batch(container:Node, scenes: Array[PackedScene]) -> void:
	for scene in scenes:
		if not scene.can_instantiate():
			push_warning("Precompiler unable to instance scene: ", scene)
			continue
		else:
			spawn_and_fire(container, scene)
		await get_tree().physics_frame
	return

## Handles special cases
func spawn_and_fire(container:Node, scene: PackedScene) -> void:
	var instance = scene.instantiate()
	
	var dont_clear:bool = false
	if instance is Weapon:
		container.add_child(instance)
		instance.shoot() # Spawns things
	elif instance is WeaponProjectile:
		container.add_child(instance)
		instance.destroy() # Spawns things
	elif instance is Explosion:
		container.add_child(instance)
		await instance.started # Signal after all effects started
	elif instance is MegaNukeExplosion:
		instance.get_game_time_seconds = func(): return 0.0 # Missing shader function
		container.add_child(instance)
	elif instance is ProceduralTerrainModifier:
		pass # Not needed
	else:
		# All unhandled types
		container.add_child(instance)
	await get_tree().process_frame # Wait a moment
	if is_instance_valid(instance) && not dont_clear:
		instance.queue_free() # Some scenes free themselves
	return
#endregion

static func find_scene_files(folders:Array[String], full_path:bool = false) -> Array[String]:
	var scenes:Array[String]
	
	# Don't know why this returns .tres in addition to .tscn, so...
	#var extensions = ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	var extensions = [".tscn"]
	
	for folder in folders:
		var files = ResourceLoader.list_directory(folder)
		for file in files:
			for extension in extensions:
				if file.ends_with(extension):
					var path:String = file
					if full_path:
						path = folder + "/" + path
					scenes.append(path)
			
	return scenes
