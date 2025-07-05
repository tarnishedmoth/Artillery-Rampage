class_name WeatherEffects extends Node2D

@onready var rain: GPUParticles2D = %Raindrops
@onready var rain_particle_process_mat:ParticleProcessMaterial = rain.process_material

func set_rain_intensity(multiplier:float) -> void:
	rain.amount_ratio = multiplier
