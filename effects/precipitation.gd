class_name WeatherEffects extends Node2D

@onready var rain: GPUParticles2D = %Raindrops
@onready var rain_particle_process_mat:ParticleProcessMaterial = rain.process_material
@onready var audio: PrecipitationAudio = %Audio

@onready var snow: GPUParticles2D = %Snow
@onready var snow_particle_process_mat:ParticleProcessMaterial = snow.process_material

enum EFFECT {
	RAIN,
	SNOW,
}

var rain_amount_tween:Tween
var snow_amount_tween:Tween

var is_snowing:bool = false
var is_raining:bool = false

var is_deleting:bool = false

func _ready() -> void:
	rain.emitting = false
	snow.emitting = false

func set_rain_intensity(intensity:float, transition_time: float = 0.0) -> void:
	if rain_amount_tween:
		if rain_amount_tween.is_running(): rain_amount_tween.kill()
			
	if not transition_time > 0.0:
		rain.amount_ratio = intensity
	else:
		rain_amount_tween = create_tween()
		rain_amount_tween.tween_property(rain, ^"amount_ratio", intensity, transition_time)
		
	if intensity > 0.0:
		audio.start(maxf(transition_time, 1.0), intensity)
	else:
		audio.stop(maxf(transition_time, 1.0))
		
func set_snow_intensity(intensity:float, transition_time: float = 0.0) -> void:
	if snow_amount_tween:
		if snow_amount_tween.is_running(): snow_amount_tween.kill()
			
	if not transition_time > 0.0:
		snow.amount_ratio = intensity
	else:
		snow_amount_tween = create_tween()
		snow_amount_tween.tween_property(snow, ^"amount_ratio", intensity, transition_time)
	
func start_effect(effect:EFFECT, intensity:float, transition_time: float) -> void:
	match effect:
		EFFECT.RAIN:
			is_raining = true
			rain.amount_ratio = 0.0
			rain.emitting = true
			set_rain_intensity(intensity, transition_time)
			
			stop_snow(transition_time)
			
		EFFECT.SNOW:
			is_snowing = true
			snow.amount_ratio = 0.0
			snow.emitting = true
			set_snow_intensity(intensity, transition_time)
			
			stop_rain(transition_time)
			
func set_intensity(effect:EFFECT, intensity:float, transition_time: float):
	match effect:
		EFFECT.RAIN:
			set_rain_intensity(intensity, transition_time)
			stop_snow(transition_time)
		EFFECT.SNOW:
			set_snow_intensity(intensity, transition_time)
			stop_rain(transition_time)
		
func stop_rain(transition_time:float) -> void:
	if is_raining:
		set_rain_intensity(0.0, transition_time)
		is_raining = false
	
func stop_snow(transition_time:float) -> void:
	if is_snowing:
		set_snow_intensity(0.0, transition_time)
		is_snowing = false

func stop_and_delete(transition_time:float) ->  void:
	var awaiting: Array[Tween]
	if is_raining:
		awaiting.append(rain_amount_tween)
	if is_snowing:
		awaiting.append(snow_amount_tween)
	
	set_rain_intensity(0.0, transition_time)
	set_snow_intensity(0.0, transition_time)
	is_deleting = true
	
	while awaiting:
		for tween: Tween in awaiting:
			if tween:
				if tween.is_running():
					continue
			awaiting.erase(tween)
			continue
	
	#await rain_amount_tween.finished or snow_amount_tween.finished
	rain.emitting = false
	snow.emitting = false
	await get_tree().create_timer(rain.lifetime).timeout
	queue_free()
