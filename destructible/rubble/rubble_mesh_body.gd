extends RigidMeshBody

@onready var _smoke_particles:CPUParticles2D = $SmokeParticles

@export_group("Particles")

@export var enable_contact_re_emission:bool = true
@export var re_emission_impulse_threshold:float = 750
@export var re_emission_min_speed:float = 5

func _init() -> void:
	if enable_contact_re_emission:
		contact_monitor = true
		max_contacts_reported = 1
	else:
		contact_monitor = false
		max_contacts_reported = 0
		
func _ready() -> void:
	if not invoke_ready or SceneManager.is_precompiler_running:
		return
	super._ready()
	
	_emit_particles()

func _emit_particles() -> void:
	print_debug("%s: Playing smoke particles" % name)
	_smoke_particles.restart()
	
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	#print_debug("%s: Speed=%f" % [name, linear_velocity.length()])

	if not enable_contact_re_emission or _smoke_particles.emitting or state.get_contact_count() == 0 or \
	 linear_velocity.length_squared() < re_emission_min_speed * re_emission_min_speed:
		return

	var impulse:Vector2 = state.get_contact_impulse(0)
	#print_debug("%s: Impulse=%f" % [name, impulse.length()])
	
	if impulse.length_squared() >= re_emission_impulse_threshold * re_emission_impulse_threshold: 
		_emit_particles()
