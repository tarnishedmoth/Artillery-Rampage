class_name AITank extends TankController

@onready var _tank:Tank = $Tank
@onready var ai_decision_state_machine: AITankStateMachine = $StateMachine

@export var min_ai_start_delay: float = 0.2
@export var max_ai_start_delay: float = 1.0

@export var min_ai_degrees_sec: float = 30
@export var max_ai_degrees_sec: float = 45

@export var min_ai_power_per_sec: float = 200
@export var max_ai_power_per_sec: float = 500

@export var min_ai_shoot_delay_time = 0.2
@export var max_ai_shoot_delay_time = 1.8

var current_action_state: AIActionState
var target_result: TankActionResult

func _ready() -> void:
	super._ready()

func begin_turn():
	super.begin_turn()
	
	print("AI began turn")
	target_result = ai_decision_state_machine.execute(tank)
	current_action_state = AIWaitingState.new(self)
	
	tank.reset_orientation()
	
func _get_tank():
	return _tank
	
func _process(delta: float) -> void:
	# Action completed
	if !is_instance_valid(current_action_state):
		return
	
	current_action_state = current_action_state.execute(delta)

func _on_tank_tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D) -> void:
	tank.kill()
	queue_free()

func _on_tank_tank_took_damage(tank: Tank, instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	pass # Replace with function body.

class AIActionState:
	var parent: AITank
	var total_time: float
	
	var elapsed_time: float = 0
	
	func _init(parent: AITank):
		self.parent = parent
	
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
	
	func _init(parent: AITank):
		super(parent)
		total_time = randf_range(parent.min_ai_start_delay, parent.max_ai_start_delay)
		
	func _next_state() -> AIActionState: return AIAimingState.new(parent)

# Aiming at target
class AIAimingState extends AIActionState:
	
	var rads_sec: float
	
	func _init(parent: AITank):
		super(parent)
		
		var target_rads = parent.target_result.angle
		var total_delta = target_rads - parent.tank.get_turret_rotation()
	
		rads_sec = deg_to_rad(randf_range(parent.min_ai_degrees_sec, parent.max_ai_degrees_sec)) * sign(total_delta)
		# No need for abs as they will have the same sign
		total_time = total_delta / rads_sec
		
		print_debug("AI Aim: degrees_sec=%f; target_angle=%f; total_delta=%f; total_time=%f"
		 % [deg_to_rad(rads_sec), rad_to_deg(total_delta), rad_to_deg(total_delta), total_time])
		
	func _next_state() -> AIActionState: return AIPoweringState.new(parent)

	func _do_execute(delta: float) -> void:
		parent.tank.aim_delta(rads_sec * delta)
	
# Setting power
class AIPoweringState extends AIActionState:
	var power_sec: float
	
	func _init(parent: AITank):
		super(parent)
		
		var target_power = parent.target_result.power
		var total_delta = target_power - parent.tank.power
	
		if is_zero_approx(total_delta):
			total_time = 0.0
		else:
			power_sec = randf_range(parent.min_ai_power_per_sec, parent.max_ai_power_per_sec) * sign(total_delta)
			total_time = total_delta / abs(power_sec)
		
	func _next_state() -> AIActionState: return AISelectWeaponState.new(parent)

	func _do_execute(delta: float) -> void:
		parent.tank.set_power_delta(power_sec * delta)

# Selecting weapon to use
class AISelectWeaponState extends AIActionState:
	func _init(parent: AITank):
		super(parent)
		# Already waiting in AIShootingState
		total_time = 0.0

	func _exit():
		var tank := parent.tank
		tank.set_equipped_weapon(parent.target_result.weapon_index)
		tank.push_weapon_update_to_hud()
		
	func _next_state() -> AIActionState: return AIShootingState.new(parent)

# Delay time after ready to shoot to actually shooting
class AIShootingState extends AIActionState:
	func _init(parent: AITank):
		super(parent)
		total_time = randf_range(parent.min_ai_shoot_delay_time, parent.max_ai_shoot_delay_time)
		
	func _exit():
		parent.tank.shoot()	
	# Last state
