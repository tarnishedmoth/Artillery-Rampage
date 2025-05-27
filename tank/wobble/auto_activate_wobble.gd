## Activates wobble on configured instance when the turn starts.
## Intended to be used by AI where no HUD or additional feedback required
## Player will use a different implementation that intercepts shoot, 
## checks if wobble is currently enabled (damage taken) and activates an interface for timing that syncs with the deviation of the wobble
extends Node

## Connect the controller for the tank
@export
var controller:TankController

## Connect the AimDamableWobble node
@export
var aim_damage_wobble:AimDamageWobble

var _turn_active:bool = false
var _wobble_ready:bool = false

## Toggle this to disable the wobble mechanic
## Note this is also changed by the difficulty modifier
@export
var enabled = true

func _ready() -> void:
	if SceneManager.is_precompiler_running:
		return
	if not controller or not aim_damage_wobble:
		push_error("%s - Missing configuration; controller=%s; aim_damage_wobble=%s" % [name, controller, aim_damage_wobble])
		return
	
	GameEvents.turn_started.connect(_on_turn_started)
	GameEvents.turn_ended.connect(_on_turn_ended)
	
	aim_damage_wobble.wobble_toggled.connect(_on_wobble_toggled)

func _on_turn_started(player: TankController) -> void:
	if player != controller:
		return
	
	print_debug("%s(%s) turn started" % [name, player])
	_turn_active = true
	
	_check_emit_conditions()

func _on_wobble_toggled(wobble_enabled:bool) -> void:
	print_debug("%s(%s) wobble toggled=%s" % [name, controller, wobble_enabled])
	_wobble_ready = wobble_enabled
	
	_check_emit_conditions()

func _on_turn_ended(player: TankController) -> void:
	if player != controller:
		return

	print_debug("%s(%s) turn started" % [name, player])
	_turn_active = false

func _check_emit_conditions() -> void:
	if _turn_active and _wobble_ready and enabled:
		print_debug("%s(%s) emitting activate_wobble on %s" % [name, controller, aim_damage_wobble.name])
		aim_damage_wobble.activate_wobble.emit()
