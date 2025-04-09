class_name Explosion extends Node2D

## Starts SFX and Particles and frees itself once all are finished.
## This class only handles CPUParticles2D and AudioStreamPlayer2D at this time.
## It will wait until all nodes assigned in the Inspector export properties have
## emitted their finished signal. Assigning a node that loops will prevent this
## node from queue_free().
## It might make sense for this to also have the functionality for damage, if we
## move it from the WeaponProjectile class.

## Will wait until all emit [signal finished] to [method queue_free] this object.
@export var particles:Array[CPUParticles2D]
# AudioStreamPlayer and AudioStreamPlayer2D are not related
# Also we could use the type of Player that layers sounds itself.
## Will wait until all emit [signal finished] to [method queue_free] this object.
@export var sfx:Array[AudioStreamPlayer2D]
## Will fade out the light's [member PointLight2D.energy] to 0 using [member lights_fade_time].
@export var lights:Array[PointLight2D]
@export_range(0.1, 10.0, 0.05,"or_greater","suffix:seconds") var lights_fade_time:float = 1.0

var _finished_sfx:int = 0
var _finished_particles:int = 0

func _ready() -> void:
	play_all()
	
func play_all() -> void:
	var emitted:int = 0
	for effect in particles:
		effect.emitting = false
		effect.one_shot = true
		effect.finished.connect(_on_particles_finished)
		effect.restart() # We could just set the nodes themselves to autoplay & not intervene
		emitted += 1
		
	for light in lights:
		fade_light(light)
	
	var started:int = 0
	for player in sfx:
		player.finished.connect(_on_sfx_finished)
		player.play() # We could just set the nodes themselves to autoplay & not intervene
		started += 1
	if emitted > 0 or started > 0:
		print_debug("Explosion handled ",started," sfx & ",emitted," particles.")
	else:
		free_after_delay() # Bad configuration
		
func check_all_finished() -> void:
	if _finished_particles == particles.size() and _finished_sfx == sfx.size():
		queue_free()
		
func free_after_delay() -> void:
	await get_tree().create_timer(5.0).timeout
	queue_free()
	
func fade_light(light: PointLight2D) -> void:
	var light_tween = create_tween()
	light_tween.tween_property(light, "energy", 0.0, lights_fade_time)
	light_tween.set_ease(Tween.EASE_IN)

func _on_sfx_finished() -> void:
	_finished_sfx += 1
	if _finished_sfx == sfx.size():
		check_all_finished()

func _on_particles_finished() -> void:
	_finished_particles += 1
	if _finished_particles == particles.size():
		check_all_finished()
