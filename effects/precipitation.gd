class_name WeatherEffects extends Node2D

@onready var rain: GPUParticles2D = %Raindrops
@onready var rain_particle_process_mat:ParticleProcessMaterial = rain.process_material

var rain_amount_tween:Tween

var is_deleting:bool = false

func _ready() -> void:
	rain.emitting = false

func set_rain_intensity(intensity:float, transition_time: float = 0.0) -> void:
	if rain_amount_tween:
		if rain_amount_tween.is_running(): rain_amount_tween.kill()
			
	if not transition_time > 0.0:
		rain.amount_ratio = intensity
		
	else:
		rain_amount_tween = create_tween()
		rain_amount_tween.tween_property(rain, ^"amount_ratio", intensity, transition_time)
	
func start_rain(intensity:float, transition_time: float) -> void:
	rain.amount_ratio = 0.0
	rain.emitting = true
	set_rain_intensity(intensity, transition_time)

func stop_rain_and_delete(transition_time:float) ->  void:
	set_rain_intensity(0.0, transition_time)
	is_deleting = true
	
	await rain_amount_tween.finished
	rain.emitting = false
	await rain.finished
	queue_free()
