class_name WeaponProjectileDeployable extends WeaponProjectile

#region-- signals
#signal completed_lifespan ## Tracked by Weapon class
#endregion


#region--Variables
# statics
# Enums
# constants
# @exports
#@export var color: Color = Color.BLACK
#@export var max_lifetime: float = 10.0 ## Self destroys once this time has passed.
@export var sfx_trigger:AudioStreamPlayer2D
@export_group("Deployables", "deploy_")
@export var deploy_scene_to_spawn: PackedScene ## Spawned upon deployment
@export var deploy_number: int = 1 ## Spawns multiple scene_to_spawn distributed evenly
@export var deploy_velocity_impulse: float = 0.0 ## Applies a one-time force to the spawned objects.
@export var deploy_delay: float = 0.5 ## Delay after first collision before deploying.
@export_group("Turn Behavior")
@export var destroy_after_deployed:bool = true
@export var destroy_after_deployables_destroyed:bool = false ## For spawning new projectiles i.e. MIRV
@export_category("NOTE: WeaponProjectile settings below do not apply to deployable scene_to_spawn.")
@export var understood:bool ## This has no effect.
#@export var 
# public
var deployed_container:Node
var deployed:Array
# _private
var _current_projectile_index: int = 1 # Current place in deploy_number while iterating
var _impacted:bool = false
var _triggered:bool = false
var _deployed_lifespan_completed:int = 0

var _explosion_played:bool = false
# @onready
#endregion


#region--Virtuals
func _ready() -> void:
	super()
	run_collision_logic = false # WeaponProjectile class
	
#endregion
#region--Public Methods
func deploy() -> void:
	_current_projectile_index = 1
	for i in deploy_number:
		var deployable = deploy_scene_to_spawn.instantiate()
		if deployable is RigidBody2D:
			_setup_deployable(deployable, true)
		else:
			_setup_deployable(deployable, false)
		if deployable is WeaponProjectile:
			if is_instance_valid(owner_tank) and is_instance_valid(source_weapon):
				deployable.set_sources(owner_tank,source_weapon)
				source_weapon._add_projectile_awaiting(deployable)
			else:
				print_debug("%s: Tank and/or weapon invalid - destroying immediately" % [name])
				deployable.explode_and_force_destroy()
				break
		_current_projectile_index += 1 # Track which one we're setting up
	
	if destroy_after_deployed: destroy()
	else: _fake_destroy()
	
func trigger() -> void:
	if _triggered: return
	_triggered = true
	#print_debug("Triggered to deploy")
	if sfx_trigger:
		sfx_trigger.play()
	if deploy_delay > 0.0:
		var timer = Timer.new()
		add_child(timer)
		timer.timeout.connect(deploy)
		timer.start(deploy_delay)
	else:
		deploy()

#endregion
#region--Private Methods
func _setup_deployable(deployable:Node2D, physics:bool = true) -> void:
	#var new_spawn = scene_to_spawn.instantiate()
	var aim_angle = TAU / deploy_number * _current_projectile_index
	
	deployable.global_position = self.global_position
	if physics:
		var spawn_velocity = Vector2(deploy_velocity_impulse, 0.0)
		deployable.linear_velocity = spawn_velocity.rotated(aim_angle)
	else:
		var initial_offset = Vector2(0.0,-deploy_velocity_impulse)
		deployable.position += initial_offset.rotated(aim_angle)
	
	if destroy_after_deployables_destroyed:
		deployable.completed_lifespan.connect(_on_deployable_lifetime_completed)
	
	if not deployed_container: deployed_container = _get_container()
	deployed_container.add_child(deployable)
	deployed.append(deployable)
	
func _on_body_entered(_body: Node) -> void: ## Internal signal
	if _impacted: return
	_impacted = true
	#print_debug("Deployable body entered")
	trigger()

func _on_deployable_lifetime_completed(_var) -> void:
	_deployed_lifespan_completed += 1
	if _deployed_lifespan_completed >= deploy_number:
		destroy()

func _fake_destroy() -> void:
	disarm()
	if explosion_to_spawn:
		spawn_explosion(explosion_to_spawn)
		_explosion_played = true
	hide()
	freeze = true
	
#endregion
