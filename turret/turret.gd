## @experimental:
## Tracks and shoots at projectiles
## Uses signals and a logic timer.
## TODO make damageable
## TODO Shoots bullets
## Configurable to teams? At least player vs AI
## TODO Tracking inaccuracy, lerp towards/past correct point, slowly/fast
class_name Turret extends Node2D

@export var debug_target:Node2D

@export var team:int = -1
@onready var gun: Weapon = %Chaingun

var logic_timer:Timer
var logic_cycle:float = 0.5

var disabled:bool = false
var _is_engaged:bool = false
var _is_shooting:bool = false

var targets:Array[Target]
var current_target:Target:
	get:
		return targets.front()

#region Internal classes
class Target extends RefCounted:
	signal expired
	var is_expired:bool = false
	var node: Node2D:
		set(value):
			node = value
		get:
			if not is_instance_valid(node): expire()
			return node if not is_expired else null
			
	var global_position: Vector2:
		set(value):
			push_warning("Abstract property") # making up terminology now
		get:
			return node.global_position if not is_expired else null
	var last_global_position: Vector2
	
	var velocity: Vector2:
		set(value):
			push_warning("Abstract property")
		get:
			return (global_position-last_global_position) if not is_expired else null
	var last_velocity: Vector2
	
	func cache() -> void:
		if not is_expired:
			last_global_position = global_position
			last_velocity = velocity
		
	func expire() -> void:
		# Target node no longer exists
		is_expired = true
		expired.emit()
		
	func _init(target_node: Node2D) -> void:
		node = target_node
#endregion

func _ready() -> void:
	GameEvents.projectile_fired.connect(_on_projectile_fired)
	
	gun.owner = self
	
	#logic_timer = Timer.new()
	#add_child(logic_timer)
	#logic_timer.timeout.connect(_on_logic_timer_timeout)
	
	if debug_target:
		start_tracking_new(debug_target)

func _physics_process(delta: float) -> void:
	if _is_engaged:
		track()

func start_tracking_new(node_to_track: Node2D) -> void:
	var new_target = Target.new(node_to_track)
	new_target.expired.connect(_on_target_expired)
	targets.append(new_target)
	engage_target(new_target)

func engage_target(target: Target = current_target) -> void:
	_is_engaged = true
	# Could play a sound effect
	track()
	shoot(6.0)
	
func disengage() -> void:
	_is_engaged = false
	# Could play a sound effect
	
func track() -> void:
	var predicted:Vector2 = predict_position(current_target)
	gun.look_at(predicted)
	
func predict_position(target: Target) -> Vector2:
	return target.global_position

func shoot(duration:float = 0.5) -> void:
	gun.shoot_for_duration(duration)
	await gun.weapon_actions_completed
	print("Finished shooting!")

func _on_target_expired(target: Target) -> void:
	targets.erase(target)
	if targets.is_empty(): disengage()
	
func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	if not projectile.max_damage > 0.0: return
	
	# If not on the same team, start tracking the projectile.
	if disabled: return
	if projectile.owner_tank:
		if projectile.owner_tank.controller.is_on_same_team_as(team):
			return
			
	start_tracking_new(projectile)
