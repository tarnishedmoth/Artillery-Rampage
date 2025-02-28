class_name PersonnelUnit extends RigidBody2D

#region-- signals
signal died()
#endregion


#region--Variables
# statics
# Enums
# constants
# @exports
@export var max_lifetime:float = 20.0
@export var logic_cycle_time:float = 0.75

@export var jump_impulse_strength: float = 350.0
@export var jump_impulse_angle_limit: float = 0.24 ## Radians
@export var min_distance_traveled_or_stuck: float = 8.0
@export var get_unstuck_frequency: int = 3 ## If stuck for this many cycles, changes logic
@export var unstuck_extra_force: float = 25.0 ## Adds more jumping force when very stuck.
# public
var goal_object
# _private
var _last_position:Vector2
var _stuck_counter:int = 0
# @onready
#endregion


#region--Virtuals
#func _init() -> void: pass
#func _enter_tree() -> void: pass
func _ready() -> void:
	GameEvents.collectible_collected.connect(_on_collectible_collected)
	
	goal_object = _find_nearest_collectible()
	start_logic_cycle()
	if max_lifetime > 0.0:
		destroy_after_lifetime(max_lifetime)
	
#func _input(event: InputEvent) -> void: pass
#func _unhandled_input(event: InputEvent) -> void: pass
#func _physics_process(delta: float) -> void: pass
#func _process(delta: float) -> void: pass
#endregion
#region--Public Methods
func start_logic_cycle(cycle_time:float = logic_cycle_time) -> void:
	cycle_time = randfn(cycle_time, 0.1)
	
	var cycle_timer = Timer.new()
	add_child(cycle_timer)
	cycle_timer.timeout.connect(_cycle_timer_timeout)
	cycle_timer.one_shot = false
	cycle_timer.start(cycle_time)

func destroy() -> void:
	died.emit()
	queue_free()
	
func destroy_after_lifetime(lifetime:float = max_lifetime) -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(destroy)
	timer.start(lifetime) 
#endregion
#region--Private Methods
func _find_nearest_collectible() -> Node2D:
	var collectibles:Array = get_tree().get_nodes_in_group(Groups.Collectible)
	if collectibles.is_empty(): return null
	
	var nearest_collectible:Node2D
	var nearest_distance:float
	
	for collectible in collectibles:
		var distance = (collectible.global_position - global_position).length()
		
		if nearest_collectible == null:
			nearest_collectible = collectible
			nearest_distance = distance
			continue
		
		if distance < nearest_distance:
			nearest_collectible = collectible
			nearest_distance = distance
	return nearest_collectible

func _get_goal_oriented_impulse(objective:Node2D) -> Vector2:
	var impulse = -transform.y * jump_impulse_strength
	if objective == null:
		return impulse
		
	if (_last_position-global_position).length() < min_distance_traveled_or_stuck:
		_stuck_counter += 1
	else:
		_stuck_counter = clampi(_stuck_counter-1, 0, 10)
		
	var tilt: float # We will tilt our hop towards the goal objective.
	var x_difference: float = objective.global_position.x - global_position.x
	
	tilt = clampf(x_difference/(TAU*2),
		-jump_impulse_angle_limit/2,
		jump_impulse_angle_limit/2)
		
	if _stuck_counter > get_unstuck_frequency:
		impulse += _stuck_counter * 10
		tilt = -tilt # Go backwards
	impulse = impulse.rotated(tilt)
	return impulse

func _cycle_timer_timeout() -> void:
	if not is_instance_valid(goal_object) or goal_object.is_queued_for_deletion():
		goal_object = null
	var impulse = _get_goal_oriented_impulse(goal_object) as Vector2
	apply_central_impulse(impulse)

# Can't seem to get PhysicsBody2D to interact naturally with Area2D
func _on_collectible_touched(collectible: CollectibleItem) -> void: # Codependence, refactor later
	print_debug("On body entered collectible")
	collectible.collect()
	destroy()
	
func _on_collectible_collected(collected: CollectibleItem) -> void:
	_find_nearest_collectible()
#endregion
