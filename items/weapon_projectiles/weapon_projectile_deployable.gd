extends WeaponProjectile

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
@export var scene_to_spawn: PackedScene ## Spawned upon deployment
@export var deploy_number: int = 1 ## Spawns multiple scene_to_spawn distributed evenly
@export var deploy_velocity_impulse: float = 0.0 ## Applies a one-time force to the spawned objects.
@export var deploy_delay: float = 0.5 ## Delay after first collision before deploying.
@export var destroy_after_deployed:bool = true

@export var sfx_trigger:AudioStreamPlayer2D
#@export var 
# public
var deployed_container:Node2D
var deployed:Array
# _private
var _impacted:bool = false
# @onready
#endregion


#region--Virtuals
#func _init() -> void: pass
#func _enter_tree() -> void: pass
func _ready() -> void:
	modulate = color
	if max_lifetime > 0.0: destroy_after_lifetime()
	#overlap.connect("body_entered", on_body_entered)
	#GameEvents.emit_projectile_fired(self)
	
	deployed_container = get_tree().current_scene
	
#func _input(event: InputEvent) -> void: pass
#func _unhandled_input(event: InputEvent) -> void: pass
#func _physics_process(delta: float) -> void: pass
#func _process(delta: float) -> void: pass

#endregion
#region--Public Methods
func deploy() -> void:
	for i in deploy_number:
		var deployable = scene_to_spawn.instantiate()
		if deployable is RigidBody2D:
			_spawn_and_setup(i, deploy_number, true)
		else:
			_spawn_and_setup(i, deploy_number, false)
	
	if destroy_after_deployed: destroy()
	
func destroy():
	#GameEvents.emit_turn_ended(owner_tank.owner) ## Moved to Weapon class.
	completed_lifespan.emit()
	queue_free()
	
#endregion
#region--Private Methods
func _spawn_and_setup(index:int, size:int, physics:bool = true) -> void:
	var new_spawn = scene_to_spawn.instantiate()
	var aim_angle = Vector2.UP.angle()
	
	new_spawn.global_position = self.global_position
	if physics:
		var spawn_velocity = Vector2(deploy_velocity_impulse, 0.0)
		new_spawn.linear_velocity = spawn_velocity.rotated(aim_angle)
	else:
		var initial_offset = deploy_velocity_impulse
		new_spawn.position += initial_offset * aim_angle
	
	if not deployed_container: deployed_container = self
	deployed_container.add_child(new_spawn)
	deployed.append(new_spawn)
#endregion


func _on_body_entered(body: Node) -> void: ## Internal signal
	if _impacted: return
	_impacted = true
	print_debug("Deployable body entered")
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(deploy)
	timer.start(deploy_delay)
	
	if sfx_trigger:
		sfx_trigger.play()
