extends RigidMeshBody

@onready var _smoke_particles:CPUParticles2D = $SmokeParticles
@onready var cooldown_timer:Timer = $CappedEmissionCooldownTimer

@export_group("Particles")

@export var enable_contact_re_emission:bool = true
@export var re_emission_impulse_threshold:float = 750
@export var re_emission_min_speed:float = 5

@export_range(1,100,1,"or_greater") var max_emissions:int = 3

var _emission_count:int = 0

func _init() -> void:
	# Won't ever turn on unless do this when constructed
	contact_monitor = true
		
func _ready() -> void:
	if not invoke_ready or SceneManager.is_precompiler_running:
		return
	super._ready()

	if enable_contact_re_emission:
		contact_monitor = true
		max_contacts_reported = 1
	else:
		contact_monitor = false
		max_contacts_reported = 0
	
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	
	_emit_particles()

func damage(projectile: WeaponPhysicsContainer, contact_point: Vector2, poly_scale: Vector2 = Vector2(1,1)):
	delete(false)
	
func _on_cooldown_timeout() -> void:
	if OS.is_stdout_verbose():
		print_debug("%s: Smoke particle emission cooldown completed" % name)
		
	_emission_count = 0
	
func _emit_particles() -> void:
	if _emission_count >= max_emissions:
		return
		
	_emission_count += 1
	
	if OS.is_stdout_verbose():
		print_debug("%s: Playing smoke particles; count=%d" % [name, _emission_count])

	if _emission_count == max_emissions:
		cooldown_timer.start()
		
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
