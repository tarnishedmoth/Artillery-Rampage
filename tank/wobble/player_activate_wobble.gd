## Activates wobble when player presses shoot button
## Intended to be used by Player where HUD is shown for visual feedback
## Intercepts shoot, 
## checks if wobble is currently enabled (damage taken) and activates an interface for timing that syncs with the deviation of the wobble
extends Node2D

## Connect the controller for the tank
@export
var controller:Player

## Connect the AimDamableWobble node
@export
var aim_damage_wobble:AimDamageWobble
 
@onready var wobble_damage_meter:WobbleDamagerMeter = $WobbleDamageMeter

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

	wobble_damage_meter.hide()

func _input(event: InputEvent) -> void:
	if not _turn_active or not _wobble_ready or not enabled:
		return

	# Make sure player can shoot with current weapon
	if event.is_action_pressed("shoot") and _can_shoot():
		if not aim_damage_wobble.wobble_activated:
			print_debug("%s(%s) intercepting shoot to activate wobble" % [name, controller])
			_start_wobble()
			# Mark event as handled so that the player controller does not process it
			get_viewport().set_input_as_handled()
		else:
			# Hide the hud 
			_end_wobble()

func _can_shoot() -> bool:
	return is_instance_valid(controller.tank) and controller.tank.check_can_shoot_weapon(controller.tank.current_equipped_weapon)

func _start_wobble() -> void:
	aim_damage_wobble.activate_wobble.emit()
	wobble_damage_meter.show()
	
func _end_wobble() -> void:
	wobble_damage_meter.hide()
	
func _on_turn_started(player: TankController) -> void:
	if player != controller:
		return
	
	print_debug("%s(%s) turn started" % [name, player])
	_turn_active = true
	
func _on_wobble_toggled(wobble_enabled:bool) -> void:
	print_debug("%s(%s) wobble toggled=%s" % [name, controller, wobble_enabled])
	_wobble_ready = wobble_enabled
	

func _on_turn_ended(player: TankController) -> void:
	if player != controller:
		return

	print_debug("%s(%s) turn started" % [name, player])
	_turn_active = false
