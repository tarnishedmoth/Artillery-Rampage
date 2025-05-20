## Alternative damage mechanic that causes the turret to wobble back and forth with greater speed and deviation as damage increases
## With this system max power should remain at 100% after damage
## Requires changes in the AITank to account for the timing aspect when this node is in the tree
## Non-intrusive on the player controller as we already account for when the player is aiming to try not to fight with player's desired angle
class_name AimDamageWobble extends Node

## Makes wobble animation start. Must be activated each turn 
signal activate_wobble

## Indicates whether wobbling is enabled and ready to be activated
## Fires whenever the enabled state changes. This does not fire each turn
signal wobble_toggled(enabled:bool)

## Deviation range vs damage pct
@export var aim_deviation_v_damage:Curve

## Speed of the deviation vs damage, in general period should decrease with more damage
@export var aim_deviation_period_v_damage:Curve

## Ease factor - see Godot "ease" function:
##- Lower than -1.0 (exclusive): Ease in-out
##- -1.0: Linear
##- Between -1.0 and 0.0 (exclusive): Ease out-in
##- 0.0: Constant
##- Between 0.0 to 1.0 (exclusive): Ease out
##- 1.0: Linear
## - Greater than 1.0 (exclusive): Ease in
## See also https://forum.godotengine.org/t/how-do-i-properly-use-the-ease-function/20396/2
@export var aim_easing:float = -1.3

@onready var _cooldown_timer:Timer = $CooldownTimer

var _tank: Tank
var _player: TankController
var enabled:bool = false
var _turn_active:bool = false

# Need a separate bool to track when we call aim_delta to recognize when a callback fires 
# due to us changing the aim vs an external player or AI action

var _modifying_aim:bool = false
var current_deviation:float 
var current_deviation_period:float
var current_rads_per_sec:float

var _deviation_delta_time:float

var _is_wobble_activated:bool = false

func _ready() -> void:
	if not aim_deviation_v_damage or not aim_deviation_period_v_damage:
		push_error("%s - aim deviation curves not specified, skipping" % name)
		return
	
	_tank = get_parent() as Tank
	if not _tank:
		# Scene may be instantiated for shader check so check we are not in the precompiler
		if not SceneManager.is_precompiler_running:
			push_error("%s - Parent must be a Tank but was %s, skipping" % [name, str(get_parent().name) if get_parent() else "NULL"])
		return 
	
	# Wait for player to be ready before enabling
	GameEvents.player_added.connect(_on_player_added)

	activate_wobble.connect(_on_wobble_activated)

# TODO: Needs to start at a max deviation as otherwise player could button mash to defeat it

func _process(delta_time: float) -> void:
	if not _is_active():
		return
	
	# Ease in/out
	# Alpha within each of the 4 phases
	var delta_phase_alpha:float = fmod((_deviation_delta_time + delta_time) / current_deviation_period, 0.25) * 4.0
	# Ease returns a number 0-1 so need to scale it to the original alpha to get the multiplier
	var ease_factor:float = ease(delta_phase_alpha, aim_easing) / maxf(delta_phase_alpha, 1e-4)
	var eased_delta:float = delta_time * ease_factor

	# Gives us the current total delta within a current cycle
	_deviation_delta_time = fmod(_deviation_delta_time + eased_delta, current_deviation_period)

	# Value 0-1 within current cycle
	var deviation_alpha: float = _deviation_delta_time / current_deviation_period
	var phase_sign:float = _get_phase_sign(deviation_alpha)

	var aim_delta_rads := phase_sign * current_rads_per_sec * eased_delta

	_modifying_aim = true
	_tank.aim_delta(aim_delta_rads)
	_modifying_aim = false

func _get_phase_sign(deviation_alpha:float) -> float:
	# Determine the phase of the animation (1-4)
	var phase:int = ceili(deviation_alpha * 4.0)
	#print_debug("phase=%d" % phase)
	match phase:
		1,4: return -1.0
		2,3,_: return 1.0

func _on_player_added(player: TankController) -> void:
	if player.tank != _tank:
		return

	print_debug("%s(%s) - Player is ready, enabling behavior" % [name, player])
	_player = player
	_connect_player_events()

func _connect_player_events() -> void:
	_tank.tank_took_damage.connect(_on_damage)
	GameEvents.aim_updated.connect(_on_aim_updated)
	GameEvents.turn_started.connect(_on_turn_started)
	GameEvents.turn_ended.connect(_on_turn_ended)

func _on_damage(_in_tank: Tank, _instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
	var total_damage_pct:float = (_tank.max_health - _tank.health) / _tank.max_health

	var deviation_deg = aim_deviation_v_damage.sample(total_damage_pct)
	var prev_enabled := enabled
	enabled = not is_zero_approx(deviation_deg) and deviation_deg > 0

	if enabled:
		# Convert to rads for tank.aim_delta
		current_deviation = deg_to_rad(deviation_deg)
		current_deviation_period = aim_deviation_period_v_damage.sample(total_damage_pct)
		# Have to sweep across the 4 phases
		current_rads_per_sec = current_deviation / current_deviation_period * 4.0

	print_debug("%s(%s) - took %f damage: total_damage_pct=%f -> enabled=%s; deviation=%f; period=%f" % 
		[name, _player, amount, total_damage_pct, enabled, deviation_deg, current_deviation_period]
	)

	if prev_enabled != enabled:
		wobble_toggled.emit(enabled)

func _on_aim_updated(player: TankController) -> void:
	if player != _player or _modifying_aim:
		return
		
	# External player action, engage cooldown so if player or AI trying to aim we don't mess with the angle
	_cooldown_timer.start()
	
func _is_active() -> bool:
	# TODO: Some of these bools are redundant, need to clean up
	return _is_wobble_activated and enabled and _turn_active and _cooldown_timer.is_stopped()

func _on_turn_started(player: TankController) -> void:
	if player != _player:
		return
	
	print_debug("%s(%s) turn started" % [name, _player])
	_turn_active = true

func _on_turn_ended(player: TankController) -> void:
	if player != _player:
		return

	print_debug("%s(%s) turn ended" % [name, _player])
	_turn_active = false
	_is_wobble_activated = false

func _on_wobble_activated() -> void:
	_is_wobble_activated = true
