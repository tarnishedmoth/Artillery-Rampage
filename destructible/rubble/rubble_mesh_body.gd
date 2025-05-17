extends RigidMeshBody

@onready var _smoke_particles:CPUParticles2D = $SmokeParticles

func _ready() -> void:
	if not invoke_ready or SceneManager.is_precompiler_running:
		return
	super._ready()
	
	_smoke_particles.restart()
