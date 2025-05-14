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

@export var wobble_error_pct_v_deg_sec: Curve

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
		 % [parent.name, deg_to_rad(rads_sec), rad_to_deg(target_rads), rad_to_deg(total_delta), total_time])
		
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
		 % [parent.name, power_sec, target_power, total_delta, total_time])
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
# If wobbling is occuring, then
# tankActionResult has the desired aim angle. If the turret is wobbling need to try and time when to shoot with appropriate random error
# To make things more unpredictable, we are still waiting the initial total_time and then AI has remaining time up to the max delay time to try and time it
# The faster the turret is wobbling the more error-prone the timing will be and will also scale by the magnitude of the wobble.
class AIShootingState extends AIActionState:
	var _wobble_active:bool = false
	var _desired_angle_rads:float
	var _angle_error_rads:float
	var _min_wait_time:float

	func _init(in_parent: AITank):
		super(in_parent)
		_min_wait_time = randf_range(parent.min_ai_shoot_delay_time, parent.max_ai_shoot_delay_time)

		var parent_children:Array[Node] = in_parent.tank.get_children()
		var wobble_node_index:int = parent_children.find_custom(func(c:Node) -> bool: return c is AimDamageWobble)
		var wobble_node:AimDamageWobble = null

		if wobble_node_index >= 0 and in_parent.wobble_error_pct_v_deg_sec:
			wobble_node = parent_children[wobble_node_index] as AimDamageWobble
			_wobble_active = wobble_node.enabled

		if  _wobble_active:
			var wobble_deg_sec:float = rad_to_deg(wobble_node.current_rads_per_sec)
			var wobble_angle:float = rad_to_deg(wobble_node.current_deviation)
			var error_pct:float = in_parent.wobble_error_pct_v_deg_sec.sample(wobble_deg_sec)
			_angle_error_rads = deg_to_rad(error_pct * wobble_angle)

			_desired_angle_rads = in_parent.target_result.angle
			total_time = parent.max_ai_shoot_delay_time
		else:
			total_time = _min_wait_time

	func _do_execute(_delta: float) -> void:
		if not _wobble_active or elapsed_time <= _min_wait_time:
			return
		
		# Determine if it is the right time to shoot
		var current_angle:float = parent.tank.get_turret_rotation()
		var angle_diff := absf(angle_difference(_desired_angle_rads, current_angle))
		if angle_diff <= _angle_error_rads:
			# Triggers exit condition
			total_time = elapsed_time
			print_debug("%s - AI Shoot - Triggering fire during wobble: current_angle=%f; target_angle=%f; angle_error=%f; elapsed_time=%fs; min_wait_time=%f; max_time=%fs" %
				[parent.name, rad_to_deg(current_angle), rad_to_deg(_desired_angle_rads), rad_to_deg(_angle_error_rads), elapsed_time, _min_wait_time, parent.max_ai_shoot_delay_time])

	# Last State	
	func _exit():
		parent.tank.shoot()
	
