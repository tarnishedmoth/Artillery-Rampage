# Abstract base class for AI and player controllers
class_name TankController extends Node2D
@export var enable_damage_before_first_turn:bool = true 
var _initial_fall_damage:bool
@export var weapons_container:Node = self ## Keep all Weapon components in here. If unassigned, self is used.

signal intent_to_act(action: Callable, owner: Object)

## Set player state that has been loaded from previous round
var pending_state: PlayerState

## identifier for team that this player is on 
## If not on a team, then -1 is used
## AI units will not attack those on the same team
@export var team:int = -1

func _ready() -> void:
	GameEvents.connect("turn_ended", _on_turn_ended)
	GameEvents.connect("turn_started", _on_turn_started)
	
	_initial_fall_damage = tank.enable_fall_damage
	
	if !enable_damage_before_first_turn:
		print_debug("TankController(%s) - _ready: Disable fall damage before first turn" % [name])
		tank.enable_fall_damage = false

func is_on_same_team_as(other: TankController) -> bool:
	if team < 0:
		return false
	return team == other.team
	
func begin_round() -> void:
	if pending_state:
		print_debug("TankController(%s) - _ready: Applying pending state" % [name])
		_apply_pending_state(pending_state)
		pending_state = null

func begin_turn() -> void:
	#tank.reset_orientation()
	tank.enable_fall_damage = _initial_fall_damage
	tank.push_weapon_update_to_hud() # TODO: fix for simultaneous fire game
	
var tank: Tank:
	get: return _get_tank()

func _apply_pending_state(state: PlayerState) -> void:
	remove_all_weapons(true)
	# Make sure decouple the weapon object from the state
	attach_weapons(state.get_weapons_copy())

	tank.apply_pending_state(state)

## Capture the current state of the player
## [param p_state] - state to use - useful for subclasses to override if we need derived player state classes
func create_player_state(p_state: PlayerState = null) -> PlayerState:
	var state: PlayerState = p_state if p_state else PlayerState.new()

	state.weapons = get_weapons()
	tank.populate_player_state(state)

	return state

func _get_tank() -> Tank:
	push_error("abstract function")
	return null
	
func get_weapons() -> Array[Weapon]:
	var weapons:Array[Weapon]
	for w in weapons_container.get_children():
		if w is Weapon:
			weapons.append(w)
	return weapons
	
func attach_weapons(weapons: Array[Weapon]) -> void:
	for w in weapons:
		weapons_container.add_child(w)
		w.global_position = tank.global_position # Probably not necessary but Weapon is a Node2D and should be simplified if so.
	tank.scan_available_weapons()
	
func remove_all_weapons(detach_immediately: bool = false) -> void:
	for w in weapons_container.get_children():
		if w is Weapon:
			w.destroy()
			if detach_immediately and w.get_parent():
				w.get_parent().remove_child(w)

func set_color(value: Color) -> void:
	tank.color = value

func _on_turn_ended(_player: TankController) -> void:
	# On any player turn ended, simulate physics	
	tank.toggle_gravity(true)

func _on_turn_started(_player: TankController) -> void:
	# Ony any player turn started, stop simulating physics
	tank.reset_orientation()

func submit_intended_action(action: Callable, player: TankController) -> void:
	print_debug("Submitted action")
	intent_to_act.emit(action, player)
