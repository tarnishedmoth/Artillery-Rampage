## Alternative damage mechanic that causes the turret to wobble back and forth with greater speed and deviation as damage increases
## With this system max power should remain at 100% after damage
## Requires changes in the AITank to account for the timing aspect when this node is in the tree
## Non-intrusive on the player controller as we already account for when the player is aiming to try not to fight with player's desired angle
class_name AimDamageWobble extends Node

## Deviation range vs damage pct
@export var aim_deviation_v_damage:Curve

## Speed of the deviation vs damage, in general period should decrease with more damage
@export var aim_deviation_period_v_damage:Curve

@onready var _cooldown_timer:Timer = $CooldownTimer

var _tank: Tank
var _player: TankController
var _enabled:bool = false
var _turn_active:bool = false

# Need a separate bool to track when we call aim_delta to recognize when a callback fires 
# due to us changing the aim vs an external player or AI action

var _modifying_aim:bool = false
var _current_deviation:float 
var _current_deviation_period:float

var _current_deviation_signed:float
var _deviation_delta_time:float

func _ready() -> void:
	if not aim_deviation_v_damage or not aim_deviation_period_v_damage:
		push_error("%s - aim deviation curves not specified, skipping" % name)
		return
	
	_tank = get_parent() as Tank
	if not _tank:
		push_error("%s - Parent must be a Tank but was %s, skipping" % [name, str(get_parent().name) if get_parent() else "NULL"])
		return 
	
	# Wait for player to be ready before enabling
	GameEvents.player_added.connect(_on_player_added)


func _process(delta_time: float) -> void:
	if not _is_active():
		return

	#Wrap total time deviation to the period. There are 4 subphases of the full period "back and forth" motion
	var delta:float = delta_time / (_current_deviation_period * 0.25)
	_deviation_delta_time = fmod(_deviation_delta_time + delta, _current_deviation_period)

	var deviation_alpha: float = _deviation_delta_time / _current_deviation_period

	#var deviation_phase_amount: float = fmod(deviation_alpha, 0.25) * 4.0
	var phase_sign:float = _get_phase_sign(deviation_alpha)

	#var deviation_angle_rads := phase_sign * _current_deviation * deviation_phase_amount
	var deviation_angle_rads := phase_sign * _current_deviation * delta

	var aim_delta:float = deviation_angle_rads #deviation_angle_rads - _current_deviation_signed

	_current_deviation_signed = deviation_angle_rads

	#print_debug("delta=%f; _deviation_delta_time=%f; phase_sign=%f; deviation_angle_rads=%f; aim_delta=%f; turret_rotation=%f" % [
		#delta, _deviation_delta_time, phase_sign, deviation_angle_rads, aim_delta, _tank.turret.rotation_degrees
	#])

	_modifying_aim = true
	_tank.aim_delta(aim_delta)
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
	
	# Cooldown when aim updated so if player or AI trying to aim we don't mess with the angle
	_cooldown_timer.timeout.connect(_on_cooldown_fired)

func _on_damage(_in_tank: Tank, _instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
	var total_damage_pct:float = (_tank.max_health - _tank.health) / _tank.max_health

	_current_deviation = aim_deviation_v_damage.sample(total_damage_pct)
	_enabled = not is_zero_approx(_current_deviation) and _current_deviation > 0

	if _enabled:
		# Convert to rads for tank.aim_delta
		_current_deviation = deg_to_rad(_current_deviation)
		_current_deviation_period = aim_deviation_period_v_damage.sample(total_damage_pct)

	print_debug("%s(%s) - took %f damage: total_damage_pct=%f -> enabled=%s; deviation=%f; period=%f" % 
		[name, _player, amount, total_damage_pct, _enabled, _current_deviation, _current_deviation_period]
	)

func _on_aim_updated(player: TankController) -> void:
	if player != _player or _modifying_aim:
		return
	
	# External player action, engage cooldown
	_cooldown_timer.start()
	
func _on_cooldown_fired() -> void:
	pass
	
func _is_active() -> bool:
	return _enabled and _turn_active and _cooldown_timer.is_stopped()

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
