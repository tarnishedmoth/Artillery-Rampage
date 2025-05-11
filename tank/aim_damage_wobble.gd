## Alternative damage mechanic that causes the turret to wobble back and forth with greater speed and deviation as damage increases
## With this system max power should remain at 100% after damage
## Requires changes in the AITank to account for the timing aspect when this node is in the tree
## Non-intrusive on the player controller as we already account for when the player is aiming to try not to fight with player's desired angle
class_name AimDamageWobble extends Node

## Deviation range vs health pct
@export var aim_deviation_v_health:Curve

@onready var _cooldownTimer:Timer = $CooldownTimer

var _tank: Tank
var _player: TankController
var _enabled:bool = false
var _turn_active:bool = false

# Need a separate bool to track when we call aim_delta to recognize when a callback fires 
# due to us changing the aim vs an external player or AI action

var _modifying_aim:bool = false

func _ready() -> void:
	if not aim_deviation_v_health:
		push_error("%s - aim deviation curve not specified, skipping" % name)
		return
	
	_tank = get_parent() as Tank
	if not _tank:
		push_error("%s - Parent must be a Tank but was %s, skipping" % [name, str(get_parent().name) if get_parent() else "NULL"])
		return 
	
	# Wait for player to be ready before enabling
	GameEvents.player_added.connect(_on_player_added)


func _process(delta: float) -> void:
	if not _is_active():
		return
	
	
func _on_player_added(player: TankController) -> void:
	if player.tank != _tank:
		return

	print_debug("%s(%s) - Player is ready, enabling behavior" % [name, player])
	_player = player
	_connect_player_events()

func _connect_player_events() -> void:
	# Only care about damage parameter, so ignore tank, instigatorController, and instigator
	_tank.tank_took_damage.connect(_on_damage.unbind(3))
	GameEvents.aim_updated.connect(_on_aim_updated)
	
	# Cooldown when aim updated so if player or AI trying to aim we don't mess with the angle
	_cooldownTimer.timeout.connect(_on_cooldown_fired)

func _on_damage(amount: float) -> void:
	print_debug("%s(%s) - took %f damage" % [name, _player, amount])

	# TODO: Sample curve and if > 0 then set _enabled to true

func _on_aim_updated(player: TankController) -> void:
	if player != _player or _modifying_aim:
		return
	
	# External player action, engage cooldown
	_cooldownTimer.start()
	
func _on_cooldown_fired() -> void:
	pass
	
func _is_active() -> bool:
	return _enabled and _turn_active and _cooldownTimer.is_stopped()

func _turn_started(player: TankController) -> void:
	if player != _player:
		return
	
	print_debug("%s(%s) turn started" % [name, _player])
	_turn_active = true

func _turn_ended(player: TankController) -> void:
	if player != _player:
		return
	
	print_debug("%s(%s) turn ended" % [name, _player])
	_turn_active = false
