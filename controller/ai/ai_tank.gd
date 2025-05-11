class_name AITank extends TankController

@onready var _tank:Tank = $Tank
@onready var ai_decision_state_machine: AITankStateMachine = $StateMachine

@export var min_ai_start_delay: float = 0.2
@export var max_ai_start_delay: float = 1.0

@export var min_ai_degrees_sec: float = 30
@export var max_ai_degrees_sec: float = 45

@export var min_ai_power_per_sec: float = 33
@export var max_ai_power_per_sec: float = 50

@export var min_ai_shoot_delay_time = 0.2
@export var max_ai_shoot_delay_time = 1.8

var current_action_state: AIActionState
var target_result: TankActionResult

func _ready() -> void:
	super._ready()

func begin_turn():
	super.begin_turn()
	
	print_debug("%s - AI began turn" % [get_parent()])
	var _popup = popup_message("Thinking...", PopupNotification.PulsePresets.Two, 2.5)
	
	before_state_selection()
	
	target_result = ai_decision_state_machine.execute(tank)
	current_action_state = AIWaitingState.new(self)
	
	tank.reset_orientation()

## Modify any ai_decision_state behaviors here
func before_state_selection():
	pass

func _get_tank():
	return _tank
	
func _process(delta: float) -> void:
	# Action completed
	if !is_instance_valid(current_action_state):
		return
	
	current_action_state = current_action_state.execute(delta)

@warning_ignore("unused_parameter")
func _on_tank_tank_killed(tank_unit: Tank, instigatorController: Node2D, instigator: Node2D) -> void:
	tank_unit.kill()
	queue_free()

@warning_ignore("unused_parameter")
func _on_tank_tank_took_damage(tank_unit: Tank, instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	pass # Replace with function body.

class AIActionState:
	var parent: AITank
	var total_time: float
	
	var elapsed_time: float = 0
	
	func _init(in_parent: AITank):
		self.parent = in_parent
	
	func execute(delta: float) -> AIActionState:
		elapsed_time += delta
		_do_execute(delta)
		if elapsed_time >= total_time:
			_exit()
			return _next_state()
		return self
	
	# Do the actual action in derived class
	func _do_execute(_delta: float) -> void:
		pass
	
	func _exit() -> void: pass
		
	# Get the next state to execute in the derived class - return null if this is the last state
	func _next_state() -> AIActionState:
		return null
		
# Reaction time for start of turn
class AIWaitingState extends AIActionState:
	
	func _init(in_parent: AITank):
		super(in_parent)
		total_time = randf_range(parent.min_ai_start_delay, parent.max_ai_start_delay)
		
	func _next_state() -> AIActionState: return AIAimingState.new(parent)

# Aiming at target
# TODO: While in the aiming state need to turn off the wobble behavior or maybe it will work itself out
# if have a cooldown on after aim_delta or aim_at called to not fight with it for a duration and the canceling stacks
# and keeps resetting the timer to start the wobbling effect
class AIAimingState extends AIActionState:
	
	var rads_sec: float
	var delta_sum: float = 0.0
	var total_delta: float
	
	func _init(in_parent: AITank):
		super(in_parent)
		
		var target_rads = parent.target_result.angle
		total_delta = target_rads - parent.tank.get_turret_rotation()
	
		rads_sec = deg_to_rad(randf_range(parent.min_ai_degrees_sec, parent.max_ai_degrees_sec)) * sign(total_delta)
		# No need for abs as they will have the same sign
		total_time = total_delta / rads_sec
		
		print_debug("%s - AI Aim: degrees_sec=%f; target_angle=%f; total_delta=%f; total_time=%f"
		 % [parent.get_parent().name, deg_to_rad(rads_sec), rad_to_deg(target_rads), rad_to_deg(total_delta), total_time])
		
	func _next_state() -> AIActionState: return AIPoweringState.new(parent)

	func _do_execute(delta: float) -> void:
		var delta_sgn:float = signf(total_delta)
		var max_delta:float = total_delta - delta_sum
		if max_delta * delta_sgn < 0:
			return
			
		var calc_delta:float = rads_sec * delta		
		var aim_delta:float = delta_sgn * minf(delta_sgn * max_delta, delta_sgn * calc_delta)
		
		#print("AIAimingState: aim_delta=%f; delta_sgn=%f; max_delta=%f; calc_delta=%f" % [aim_delta,delta_sgn,max_delta,calc_delta])

		if not is_zero_approx(aim_delta):
			parent.tank.aim_delta(aim_delta)
			delta_sum += aim_delta

# Setting power
class AIPoweringState extends AIActionState:
	var power_sec: float
	var delta_sum: float = 0.0
	var total_delta: float
	
	func _init(in_parent: AITank):
		super(in_parent)
		
		var target_power = parent.target_result.power
		# Power is set as a percent [0-100]
		total_delta = (target_power - parent.tank.power) / parent.tank.max_power * 100.0
	
		if is_zero_approx(total_delta) or is_nan(total_delta):
			total_time = 0.0
		else:
			power_sec = randf_range(parent.min_ai_power_per_sec, parent.max_ai_power_per_sec) * sign(total_delta)
			total_time = total_delta / power_sec
			
		print_debug("%s - AI Power: power_sec=%f; target_power=%f; total_delta=%f; total_time=%f"
		 % [parent.get_parent().name, power_sec, target_power, total_delta, total_time])
	func _next_state() -> AIActionState: return AISelectWeaponState.new(parent)

	func _do_execute(delta: float) -> void:
		var delta_sgn:float = signf(total_delta)
		var max_delta:float = total_delta - delta_sum
		if max_delta * delta_sgn < 0:
			return
		
		var calc_delta:float = power_sec * delta
		var power_delta:float = delta_sgn * minf(delta_sgn * max_delta, delta_sgn * calc_delta)
		
		#print("AIPoweringState: power_delta=%f; delta_sgn=%f; max_delta=%f; calc_delta=%f" % [power_delta,delta_sgn,max_delta,calc_delta])
		if not is_zero_approx(power_delta):
			parent.tank.set_power_delta(power_delta)
			delta_sum += power_delta
			
# Selecting weapon to use
class AISelectWeaponState extends AIActionState:
	func _init(in_parent: AITank):
		super(in_parent)
		# Already waiting in AIShootingState
		total_time = 0.0

	func _exit():
		var tank := parent.tank
		tank.set_equipped_weapon(parent.target_result.weapon_index)
		tank.push_weapon_update_to_hud()
		
	func _next_state() -> AIActionState: return AIShootingState.new(parent)

# Delay time after ready to shoot to actually shooting
# TODO: tankActionResult has the desired aim angle. If the turret is wobbling need to try and time when to shoot with appropriate random error
# Probably need to do nothing for min_ai_shoot_delay time and then try to time up to max_ai_shoot_delay_time
# One way to hack this is to override _do_execute. Initially set the total time to the max_ai_shoot_delay time to force shoot by then
# Then in _do_execute if detect right time to shoot after ai_shoot_delay_time elapses, then set total_time = elapsed_time which will cause exit to fire and
# shooting to occur
# All of this only occurs if the wobbling behavior is active so would need to search for that node type in the tree
class AIShootingState extends AIActionState:
	func _init(in_parent: AITank):
		super(in_parent)
		total_time = randf_range(parent.min_ai_shoot_delay_time, parent.max_ai_shoot_delay_time)
		
	func _exit():
		parent.tank.shoot()
	# Last state
