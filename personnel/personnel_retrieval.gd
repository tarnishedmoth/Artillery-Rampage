extends RigidBody2D

#region-- signals
signal died()
#endregion


#region--Variables
# statics
# Enums
# constants
# @exports
@export var max_lifetime:float = 10.0
@export var logic_cycle_time:float = 0.9

@export var jump_impulse_strength: float = 100.0
# public
var goal_object
# _private
# @onready
#endregion


#region--Virtuals
#func _init() -> void: pass
#func _enter_tree() -> void: pass
func _ready() -> void:
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
func _get_goal_oriented_impulse(objective:Node2D = goal_object) -> Vector2:
	var impulse = -transform.y * jump_impulse_strength
	if objective == null:
		return impulse
		
	var tilt: float # We will tilt our hop towards the goal objective.
	var x_difference: float = objective.global_position.x - global_position.x
	
	tilt = clampf(x_difference/TAU, -PI/2, PI/2)
	impulse = impulse.rotated(tilt)
	return impulse

func _cycle_timer_timeout() -> void:
	var impulse = _get_goal_oriented_impulse() as Vector2
	apply_central_impulse(impulse)
	
#endregion
