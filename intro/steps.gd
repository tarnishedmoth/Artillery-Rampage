extends Control

@export var show_imaginary_steps:bool = true

const STEPS_WRITING:Array[String] = [
	"Sorting laundry...",
 	"Parsing astral orientation...",
	"Forming critical molded objects...",
	"Firing kilns...",
	"Taking short positions...",
	"Holding stocks...",
	"Indexing llamas...",
	"Calibrating whimsy...",
	"Defragmenting player memory...",
	"Syncing signals...",
	"Plotting orbits...",
	"Preloading magazines...",
	"Arming forces...",
	"Layering backgrounds...",
	"Connecting scaffolds...",
	"Inspecting parameters...",
	"Harmonizing harmonics...",
	"Aligning thrusters...",
	"Adjusting temporal field...",
	"Spraying for insects...",
	"Participating in charity...",
	"Submitting entries...",
	"Flattening layers...",
	"Arguing variables...",
	"Spinning spanners...",
	"Watering vegetation...",
	"Predicting weather patterns...",
	"Assembling tanks...",
	"Cleaning arsenals...",
	"Employing NPCs...",
	"Recording responses...",
	"Verifying user options...", 
	"Modeling lattices...",
	"Filling arrays...",
	"Setting traps...",
	"Orienting sky dome...",
	"Projecting digital space textures...",
	"Appropriating affine filtering...",
	"Wiping pixel residue...",
	"Hinging logic gates...",
	"Quantizing angles...",
	"Calculating risk...",
	"Recalculating risk...",
	"Skipped: employ agendas...",
	"Navigating handrolled code...",
	"Inverting entropy!",
	"Mapping confusion clusters...",
	"Overclocking behavioral reactivity...",
	"Spawning sub-subroutines...",
	"Rewriting similar methods...",
	"Duplicating functionality...",
	"Compartmentalizing intricacies...",
	"Absorbing floating point errors...",
	"Absolving blames...",
	"Tracing references...",
	"Using protractors...",
	"Drafting architecture...",
	"Clearing assembly lines...",
	"Arresting coroutines...",
	"Yielding computational control...",
	"Transmuting efforts into void...",
	"Aligning firewall mirrors...",
	"Dialing down world temperatures...",
	"Preloading assets...",
	"Drawing textures...",
	"Sculpting models...",
	"Caching sounds...",
	"Starting programs...",
	"Converting degrees to radians...",
	"Searching documentation...",
	"Overcooking irrelevant aspects...",
	"Amending commits...",
	"Forking new branches...",
	"Trading pink slips...",
	"Browsing marketplace...",
	"Investigating sidetracks...",
	"Parsing serialized files...",
	"Increasing physics precision...",
	"Investigating unobservable switch...",
	"Simulating projectiles...",
	"Spawning collectibles...",
	"Customizing characters...",
	"Calibrating white balance...",
	"Curving contrast...",
	"Delegating tasks...",
	"Seeking real results...",
	"Reflecting on logs...",
	"Compiling errors...",
	"Preparing utilities...",
	"Feeding codebase...",
	"Deleting commented code...",
	"Adjusting resolution...",
	"Crafting menu buttons...",
	"Organizing level structures...",
	"Structuring enemy militaries...",
	"Dozing unused facilities...",
	"Calling subroutines to surface...",
	"Baking HTTP cookies...",
	"Spinning alternate web theories...",
	"Cutting with the grain...",
	"Calling familiar numbers...",
	"Mapping dimensions...",
	"Fueling vehicles...",
	"Spawning spawners...",
	"Attaching scripts...",
	"Renaming constants...",
	"Patching gamebreakers...",
	"Infusing logic with global seed...",
	"Attributing credits...",
	"Applying to HomeTeam...",
	"Darkening shadows...",
	"Dodging highlights...",
	"Removing asset projects...",
	"Ignoring obstructive practices...",
	"Braking panel seams...",
	"Acquiring protective equipment...",
	"Publishing safety data sheets...",
	"Complying with regulations...",
	"Running required countermeasures...",
	"Specifying hat colors...",
	"Sharpening null pointers...",
	"Distributing resistance...",
	"Halting recursions...",
	"Simulating competence...",
	"Randomizing randomizer...",
	"Confounding staff...",
	"Counting bit depths...",
	"Straightening pixel rows...",
	"Plotting dimensional grids...",
	"Sanitizing work surfaces...",
	"Rewatching classics...",
	"Cruising avenues...",
	"Capping environment energy...",
	"Cascading shadows...",
	"Queueing soundtrack...",
	"Superceding parent methods...",
	"Reparenting orphaned nodes...",
	"Commemorating annual events...",
	"Congregating masses...",
	"Clamping trajectories...",
	"Priming carburetors...",
	"Winterizing dormant projects...",
	]
var imaginary_steps_writing:Array[String]

var display_queue:Array
var steps_taken:int

var show_steps_frequency:float:
	get: return randfn(0.25, 0.1)

var running:bool = false
var _running_delta:float = 0.0

func _ready() -> void:
	if not show_imaginary_steps:
		%ProgressNotesUI.hide()
	else:
		imaginary_steps_writing = STEPS_WRITING.duplicate()
		imaginary_steps_writing.shuffle()
		
func _physics_process(delta: float) -> void:
	if running:
		_running_delta += delta
		if _running_delta > show_steps_frequency:
			_running_delta = 0.0
			add_imaginary_steps(1)
			var note = display_queue.pop_front()
			note.show()
	
func start() -> void:
	Juice.fade_in(self,Juice.SMOOTH)
	if not visible: show()
	
	# Wait a moment, move progress bar
	var tween = create_tween()
	tween.tween_callback(add_imaginary_steps.bind(1, true))
	tween.tween_property(%ProgressBarUI, "value", 100.0, Juice.FAST).from(0.0).set_trans(Tween.TRANS_CIRC)
	tween.set_loops(2)
	
	await tween.finished
	running = true
	
	%LoadingLabel.set_visible_characters(0)
	%LoadingLabel.text = "Loading..."
	TypewriterEffect.apply_to(%LoadingLabel)
	
	
func exit() -> void:
	# Wait, and then exit
	var tween = create_tween()
	#tween.tween_interval(finished_wait)
	tween.tween_property(%ProgressBarUI, "modulate", Color.TRANSPARENT, Juice.PATIENT)
	tween.tween_callback(%LoadingLabel.set.bind("text", ""))
	await tween.finished
	running = false

func _on_precompilation_progress_changed(progress:float) -> void:
	var reduced_factor:float = 0.35
	%ProgressBarUI.value = progress * 100 * reduced_factor
	#if progress >= 0.98: _tween_to_end()
	
func _on_precompilation_entities_count_changed(count:int) -> void:
	add_imaginary_steps(count / 3)
	%NumberOfEntitiesUI.text = str(count) + " entities"

func _on_precompilation_completed() -> void:
	# Fill the progress bar, then exit
	var tween = create_tween()
	tween.tween_property(%ProgressBarUI, "value", 100.0, Juice.PATIENT)
	tween.tween_callback(exit)
	
func add_imaginary_steps(quantity:int, show_immediately:bool = false) -> void:
	for i in quantity:
		steps_taken += 1
		var new_label = ProgressStep.new(show_immediately)
		# Loop through writing array in order.
		var index = wrap(steps_taken, 0, imaginary_steps_writing.size())
		
		new_label.text = imaginary_steps_writing[index]
		%ProgressNotesUI.add_child(new_label)
		display_queue.append(new_label)
		
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
