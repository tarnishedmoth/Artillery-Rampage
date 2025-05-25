class_name PersonnelUnit extends RigidBody2D

#region-- signals
signal died()
#endregion


#region--Variables
# statics
# Enums
# constants
# @exports
@export var max_lifetime:float = 55.0
@export var logic_cycle_time:float = 0.85

@export var jump_impulse_strength: float = 350.0
@export var jump_impulse_angle_limit: float = 0.24 ## Radians
@export var min_distance_traveled_or_stuck: float = 15.0
@export var get_unstuck_frequency: int = 3 ## If stuck for this many cycles, changes logic
@export var unstuck_extra_force: float = 25.0 ## Adds more jumping force when very stuck.

@onready var flare_gun: Weapon = $Weapons/FlareGun

# public
var goal_object
# _private
var _last_position:Vector2
var _stuck_counter:int = 0
var _is_dead:bool = false
var _requested_pickup:bool = false
var _full_pockets:bool = false
# @onready
#endregion


#region--Virtuals
#func _init() -> void: pass
#func _enter_tree() -> void: pass
func _ready() -> void:
	GameEvents.collectible_collected.connect(_on_collectible_collected)
	GameEvents.copter_arrived_for_pickups.connect(_on_copter_arrived_for_pickups)
	
	#goal_object = _find_nearest_collectible()
	start_logic_cycle()
	if max_lifetime > 0.0:
		die_after_lifetime(max_lifetime)
	
#func _input(event: InputEvent) -> void: pass
#func _unhandled_input(event: InputEvent) -> void: pass
#func _physics_process(delta: float) -> void: pass
#func _process(delta: float) -> void: pass
#endregion
#region--Public Methods
func start_logic_cycle(cycle_time:float = logic_cycle_time) -> void:
	#if _is_dead: return
	cycle_time = randfn(cycle_time, 0.1)
	
	var cycle_timer = Timer.new()
	add_child(cycle_timer)
	cycle_timer.timeout.connect(_logic_cycle_timer_timeout)
	cycle_timer.one_shot = false
	await get_tree().create_timer(randf()).timeout
	cycle_timer.start(cycle_time)

func destroy() -> void:
	if _is_dead: return
	_full_pockets = true
	
	var tween = Juice.fade_out(self, Juice.PATIENT)
	tween.tween_callback(queue_free)
	
func die_after_lifetime(lifetime:float = max_lifetime) -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(die)
	timer.start(lifetime) 
	
func die() -> void:
	if _is_dead: return
	_is_dead = true
	lock_rotation = false
	
	died.emit()
	var tween = Juice.fade_out(self, Juice.VERYLONG)
	tween.tween_callback(queue_free)
	
func request_pickup() -> void:
	if _requested_pickup: return
	_requested_pickup = true
	shoot_flare()
	GameEvents.personnel_requested_pickup.emit(self)
	
func shoot_flare() -> void:
	if not flare_gun.is_equipped:
		flare_gun.equip()
	flare_gun.shoot()
#endregion
#region--Private Methods
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
		impulse += _stuck_counter * unstuck_extra_force
		tilt = -tilt # Go backwards
	impulse = impulse.rotated(tilt)
	return impulse
	
func _find_nearest_collectible() -> Node2D:
	if get_tree().get_node_count_in_group(Groups.Collectible) == 0:
		request_pickup()
		if is_instance_valid(goal_object):
			return
	var collectibles:Array = get_tree().get_nodes_in_group(Groups.Collectible)
	#if collectibles.is_empty(): return null
	
	var nearest_collectible:Node2D = null
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

func _logic_cycle_timer_timeout() -> void:
	if _is_dead: return
	#print(goal_object)
	if not is_instance_valid(goal_object) or goal_object.is_queued_for_deletion():
		goal_object = null
	if goal_object == null:
		goal_object = _find_nearest_collectible()
		if goal_object == null:
			request_pickup()
	else:
		# Pickup Copter
		if goal_object.has_method("load_passenger"):
			var distance = (goal_object.global_position - global_position).length()
			if distance < 64.0:
				goal_object.load_passenger(self)
			
	var impulse = _get_goal_oriented_impulse(goal_object) as Vector2
	apply_central_impulse(impulse)

# Can't seem to get PhysicsBody2D to interact naturally with Area2D
func _on_collectible_touched(collectible: CollectibleItem) -> void: # Codependence, refactor later
	#print_debug("On body entered collectible")
	_full_pockets = true
	collectible.collect()
	request_pickup()
	
func _on_collectible_collected(_collected: CollectibleItem) -> void:
	if _full_pockets or _is_dead or _requested_pickup: return
	_find_nearest_collectible() # We could go again but typically it's a waste of time
	
func _on_copter_arrived_for_pickups(copter) -> void:
	if _requested_pickup: goal_object = copter
	
func _on_copter_left_airspace(_copter) -> void:
	#cry
	pass
#endregion
