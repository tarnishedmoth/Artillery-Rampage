extends WeaponProjectile

enum MissileBehaviorType {
	Downward,
	Homing
}

@export var behavior:MissileBehaviorType = MissileBehaviorType.Downward
@export var thrust_sfx:AudioStreamPlayer2D
@export var acquired_target_sfx:AudioStreamPlayer2D
@export var max_thrust:float = 1500.0
@export var delay_before_targeting:float = 0.5
@export var delay_before_thrusting:float = 0.68
@export var thrust_decay_time:float = 1.5
@export var show_debug_targets:bool = false
@onready var debug_target = $Debug_Target
@onready var debug_target2 = $Debug_Target2

@onready var last_position:Vector2 = global_position
@onready var thruster:Marker2D = $MissileThruster

var target:Vector2
var _thrust:float = 1.0
var _last_force:Vector2 = Vector2(0.0,0.0)

var _targeting:bool = false
var _thrusting:bool = false

func _ready() -> void:
	super()
	delay_targeting()
	delay_thrusting()

func _integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	#super()
	if not _thrusting: return
	var force: Vector2
	var vector = Vector2.RIGHT.rotated(thruster.global_rotation)
	force = vector * _thrust * max_thrust
	apply_central_force(force)
	_last_force = force
	
func _physics_process(_delta: float) -> void:
	if _targeting:
		targeting()

func delay_targeting(time:float = delay_before_targeting) -> void:
	await get_tree().create_timer(time).timeout
	target = _find_nearest_target()
	_targeting = true

func delay_thrusting(time:float = delay_before_thrusting) -> void:
	await get_tree().create_timer(time).timeout
	_thrusting = true
	if thrust_sfx: thrust_sfx.play()
	await get_tree().create_timer(thrust_decay_time).timeout
	_thrusting = false
	if thrust_sfx: thrust_sfx.stop()
	
func targeting() -> void:
	var desired_target
	var final_target
	match behavior:
		MissileBehaviorType.Downward:
			desired_target = Vector2(global_position.x, global_position.y + 1.0)
		MissileBehaviorType.Homing:
			var distance = global_position.distance_to(target)
			var gravity_compensated_target = target + Vector2.UP * sqrt(distance) * 2 # This is very wrong but I am not good at this math
			desired_target = gravity_compensated_target
			
	final_target = global_position+lerp(global_transform.x, global_position.direction_to(desired_target),0.15)
	if show_debug_targets:
		debug_target.global_position = final_target
		debug_target2.global_position = desired_target
	look_at(final_target)

func _find_nearest_target() -> Vector2:
	var targets:Array
	if owner_tank.is_in_group(Groups.Player):
		targets = get_tree().get_nodes_in_group(Groups.Bot) # Target AI units
	else:
		targets = get_tree().get_nodes_in_group(Groups.Player) # Target player units
	
	var nearest_target:Node2D = null
	var nearest_distance:float
	
	if not targets.is_empty(): # Should acquire a target, lol
		if acquired_target_sfx: acquired_target_sfx.play()
		
	for foo in targets:
		var distance = (foo.global_position - global_position).length()
		
		if nearest_target == null:
			nearest_target = foo
			nearest_distance = distance
			continue
		
		if distance < nearest_distance:
			nearest_target = foo
			nearest_distance = distance
			
	if show_debug_targets:
		debug_target.show()
		debug_target2.show()
	return nearest_target.global_position
