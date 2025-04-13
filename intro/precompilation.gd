## Avoid hitches and skips by previewing all of the game entities before loading the game.
## Will load and instantiate every tscn in each directory added.
## [i]Does not[/i] recursively load subdirectories.
extends Node2D

signal completed

# Sorry this is a spaghetti of real things and fake gamified things

# Real things
@export_dir var scene_folders:Array[String] ## Loads all tscn files in these directories
@export var batch_size:int = 2 ## Scenes to instantiate at once

# Not real things
@export var show_imaginary_steps:bool = true
@export var imaginary_steps:Array[String]
var show_steps_frequency:float:
	get: return randfn(0.25, 0.1)

@export var initial_percentage:float = 10.0

var total_scenes:int
var remainder:int # The number of scenes left to spawn.
var steps:int
var notes:Array[ProgressStep]

var running:bool = false
var _running_delta:float = 0.0

#region Public
func run() -> void:
	if not visible: show()
	Juice.fade_in(self,Juice.FAST)
	if not show_imaginary_steps: %ProgressNotesUI.hide()
	imaginary_steps.shuffle()
	
	# Wait a moment, move progress bar
	var tween = create_tween()
	tween.tween_callback(add_imaginary_steps.bind(1, true))
	tween.tween_property(%ProgressBarUI, "value", 100.0, Juice.PATIENT).from(0.0).set_trans(Tween.TRANS_CIRC)
	tween.tween_callback(add_imaginary_steps.bind(1, true))
	tween.tween_callback(%LoadingLabel.set.bind("text", "Done."))
	tween.tween_callback(add_imaginary_steps.bind(1, true))
	tween.tween_property(%ProgressBarUI, "modulate", %ProgressBarUI.modulate, Juice.SNAPPY).from(Color.DODGER_BLUE).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	
	# Run logic
	#if not OS.is_debug_build():
	await precompile_all_configured_scenes()
	
	# Wait, and then exit
	tween = create_tween()
	#tween.tween_interval(finished_wait)
	tween.tween_property(%ProgressBarUI, "modulate", Color.TRANSPARENT, Juice.PATIENT)
	tween.tween_callback(%LoadingLabel.set.bind("text", ""))
	await tween.finished
	running = false
	
	# TODO Reset the game state in case anything was altered
	completed.emit()
	
func _physics_process(delta: float) -> void:
	if running:
		_running_delta += delta
		if _running_delta > show_steps_frequency:
			_running_delta = 0.0
			add_imaginary_steps(1)
			var note = null
			while note == null:
				note = notes.pop_front()
			note.show()

## The main method
func precompile_all_configured_scenes() -> void:
	const print_colors:String = "[bgcolor=grey][color=black]"
	%LoadingLabel.set_visible_characters(0)
	%LoadingLabel.text = "Loading..."
	TypewriterEffect.apply_to(%LoadingLabel)
	running = true # Used for visual elements
	
	## Get full resource paths through ResourceLoader and set up the UI elements
	var scene_paths = find_scene_files(scene_folders, true)
	total_scenes = scene_paths.size() # For the visual elements
	remainder = total_scenes
	add_imaginary_steps(total_scenes/3)
	%NumberOfEntitiesUI.text = str(total_scenes) + " entities"
	
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
		_on_progress_updated()
	
	## Completed precompiling
	pass
	
## Spawn Decorative UI elements
func add_imaginary_steps(quantity:int, show_immediately:bool = false) -> void:
	for i in quantity:
		steps += 1
		var new_label = ProgressStep.new(show_immediately)
		# Loop through imaginary_steps[String] in order.
		var index = wrap(steps, 0, imaginary_steps.size())
		new_label.text = imaginary_steps[index]
		%ProgressNotesUI.add_child(new_label)
		notes.append(new_label)

func _on_progress_updated() -> void:
	var reduced_factor:float = 0.35
	var value:float = (100.0-(float(remainder)/float(total_scenes) * 100)) * reduced_factor
	%ProgressBarUI.value = value
	if value >= 100.0 * reduced_factor: _tween_to_end()

func _tween_to_end() -> void:
	var tween = create_tween()
	var duration = Juice.PATIENT
	tween.tween_property(%ProgressBarUI, "value", 100.0, duration)

func spawn_batch(container:Node, scenes: Array[PackedScene]) -> void:
	for scene in scenes:
		if not scene.can_instantiate():
			push_warning("Precompiler unable to instance scene: ", scene)
			continue
		else:
			spawn_and_fire(container, scene)
		await get_tree().process_frame
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

#region Inner classes
## Purely decorative label with juice
class ProgressStep extends Label:
	var attack:float = 0.2 ## Transition into view
	var hold:float = 0.85 ## Time to remain in place
	var release:float = 0.6 ## Transition out of view
	
	var immediate:bool = false ## Play immediately on ready.
	
	var tween: Tween
	
	func _init(play:bool = false) -> void: immediate = play
	
	func _enter_tree() -> void:
		hide()
		# Use modulate for target effect,
		# and self_modulate for initial effect
		self_modulate = Color.TRANSPARENT
	
	func _ready() -> void:
		if immediate:
			start()
		else:
			# Start when it becomes visible
			visibility_changed.connect(_on_visibility_changed)
		
	## This is also effectively triggered by [method Label.show].
	func start() -> void:
		if tween: tween.kill()
		tween = create_tween()
		
		if not visible: show() # When immediate start && hidden node
		
		# Juice
		tween.tween_property(self, "self_modulate", Color.WHITE, attack)
		tween.tween_interval(hold)
		await tween.finished
		stop()
		
	func stop() -> void:
		if tween: tween.kill()
		tween = create_tween().set_parallel(true)
		tween.tween_property(self, "modulate", Color.TRANSPARENT, release)
		tween.tween_property(self, "position:x", position.x-40.0, release)
		tween.chain().tween_callback(queue_free)
		
	func _on_visibility_changed() -> void:
		if visible:
			start()
#endregion
