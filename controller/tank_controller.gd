## Abstract base class for AI and player controllers
class_name TankController extends Node2D

@export var enable_damage_before_first_turn:bool = true 
var _initial_fall_damage:bool
@export var weapons_container:Node = self ## Keep all Weapon components in here. If unassigned, self is used.

signal intent_to_act(action: Callable, owner: Object)
## This is set each turn start with the return of [method check_if_must_skip_actions].
var can_take_action:bool = true
## This allows for shooting more than once per turn, for instance.
var actions_per_turn:int = 1

## Set player state that has been loaded from previous round
var pending_state: PlayerState

## identifier for team that this player is on 
## If not on a team, then -1 is used
## AI units will not attack those on the same team
@export var team:int = -1

var popups:Array
var signals_connected:bool = false
var _active_turn:bool = false

const tank_override_meta_key:StringName = &"tank_override"

func _ready() -> void:
	GameEvents.turn_ended.connect(_on_turn_ended)
	GameEvents.turn_started.connect(_on_turn_started)

	on_tank_added()

## Called when tank is added to the scene
## Normally this is called in [member _ready] but also called when replacing the tank in [member replace_tank]
func on_tank_added() -> void:
	tank.actions_completed.connect(_on_tank_actions_completed)

	# Need to auto-end turn if killed during active turn and other intents will not fire
	tank.tank_killed.connect(_on_tank_killed)
	_initial_fall_damage = tank.enable_fall_damage

	if !enable_damage_before_first_turn:
		print_debug("TankController(%s) - _ready: Disable fall damage before first turn" % [name])
		tank.enable_fall_damage = false

func _to_string() -> String:
	return name
	
func is_on_same_team_as(other) -> bool:
	if other is TankController:
		if team < 0:
			return false
		return team == other.team
	else:
		return team == other # int comparison
	
func begin_round() -> void:
	if pending_state:
		print_debug("TankController(%s) - _ready: Applying pending state" % [name])
		_apply_pending_state(pending_state)
		pending_state = null

func begin_turn() -> void:
	_active_turn = true
	
	tank.push_weapon_update_to_hud() # TODO: fix for simultaneous fire game
	can_take_action = check_if_must_skip_actions() # Check this in Player/AI for behavior. Will submit an empty action (to skip) this turn, if true.
	
func _on_tank_killed(_tank: Tank, _instigatorController: Node2D, _instigator: Node2D) -> void:
	if _active_turn:
		print_debug("TankController(%s) - _on_tank_killed: Ending turn" % [name])
		end_turn()
	else:
		print_debug("TankController(%s) - _on_tank_killed: Not active turn" % [name])
	
func end_turn() -> void:
	if not _active_turn:
		print_debug("TankController(%s) - end_turn: Not active turn" % [name])
		return

	_active_turn = false
	clear_all_popups()
	GameEvents.turn_ended.emit(tank.controller) # Because I'm not sure if "self" is abstract in this context
	
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
	
## Call before adding controller to scene to swap out the tank that will be used
## This should be done before to avoid any scene tree init issues
## Can use this to allow player to select a different type of tank to use - light, heavy, etc
func replace_tank(new_tank:Tank) -> void:
	# replace existing tank with new_tank
	var current_tank:Tank = _get_tank()

	if is_instance_valid(current_tank) and current_tank.get_parent() == self:
		# Put new tank in same child order as original tank
		var current_index:int = current_tank.get_index()
		var existing_owner:Node = current_tank.owner

		var controller_added_children: Array[Node] = _duplicate_controller_added_tank_nodes(current_tank)
		remove_child(current_tank)
		current_tank.queue_free()

		_do_replace_tank(new_tank)

		add_child(new_tank)
		for child in controller_added_children:
			new_tank.add_child(child)
			
		new_tank.owner = existing_owner

		move_child(new_tank, current_index)

		# Remove any meta flags so this doesn't get repeated
		remove_meta(tank_override_meta_key)

		on_tank_added()

		GameEvents.tank_changed.emit(self, current_tank, new_tank)

		# TODO: This doesn't copy over any of the child nodes of tank added to the tank controller
		# Such as the set_initial_aim or the new wobble damage nodes
	else:
		# Flag for later
		set_meta(tank_override_meta_key, new_tank)

func _duplicate_controller_added_tank_nodes(current_tank: Tank) -> Array[Node]:
	var controller_added_children: Array[Node] = []

	for child in current_tank.get_children():
		# By default the scene root that the node is part of is the owner
		# If the child's owner is the tank, then it was part of the tank scene
		# We want to duplicate any children that have the TankController as the owner 
		# as these were added the controller derived scene
		if child.owner == self:
			controller_added_children.append(child.duplicate())
	return controller_added_children
	
## Override in derived class to replace _tank
## new_tank is not yet in the tree
func _do_replace_tank(_new_tank:Tank) -> void:
	pass

func _enter_tree() -> void:
	if not has_meta(tank_override_meta_key):
		return
	var tank_override:Tank = get_meta(tank_override_meta_key) as Tank
	if is_instance_valid(tank_override):
		replace_tank(tank_override)
		
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
	
func get_color() -> Color:
	return tank.color

func _on_turn_ended(_player: TankController) -> void:
	# On any player turn ended, simulate physics	
	tank.toggle_gravity(true)

func _on_turn_started(_player: TankController) -> void:
	# Ony any player turn started, stop simulating physics
	tank.reset_orientation()
	
	# Enable fall damage for all players once the first turn starts if previously disabled
	# as the initial positions have settled by first player start
	tank.enable_fall_damage = _initial_fall_damage

func _on_tank_actions_completed(_tank: Tank) -> void:
	end_turn()

func submit_intended_action(action: Callable, player: TankController) -> void:
	if can_take_action:
		print_debug("Submitted action")
		intent_to_act.emit(action, player)
	else:
		skip_action(player)

func skip_action(player: TankController) -> void:
	#print_debug("Skipping taking actions (this turn)")
	
	# Provide intent_to_act() with an empty dummy callable, to do nothing and advance turns.
	intent_to_act.emit(_skip, player) # Required for turn to advance as RoundDirector is awaiting our ticket
	await get_tree().process_frame
	end_turn()
	
func _skip() -> void:
	pass

## Check for disabling effects like EMP
func check_if_must_skip_actions() -> bool:
	if tank.debuff_emp_charge > tank.debuff_disabling_emp_charge_threshold:
		#print_debug("EMP charge above threshold--turn must be skipped")
		var _popup = popup_message(PopupNotification.Contexts.EMP_DISABLED)
		return false
		
	return true

#region Popup Notifications
func popup_message(message:String, pulses:Array = PopupNotification.PulsePresets.Three, lifetime:float = 0.0) -> PopupNotification:
	var popup = PopupNotification.constructor(message, pulses)
	if lifetime > 0.0: # Allows for default from the instance's export var
		popup.lifetime = lifetime
	
	tank.tankBody.add_child(popup) # Because the tankBody moves independently of the tank node...
	
	var offset = Vector2(0.0, 24.0) + (popups.size() * Vector2(0.0, 48.0)) # They stack
	
	# TODO place above tank if near bottom of screen (would be cut off)
	popup.global_position = tank.tankBody.global_position + offset
	var actual = get_global_transform_with_canvas().origin
	if actual.y + 96.0 > get_viewport().get_visible_rect().size.y:
		popup.global_position = tank.tankBody.global_position - offset*3
	
	popup.completed_lifetime.connect(_on_popup_completed_lifetime)
	
	popups.append(popup)
	return popup
	
func clear_all_popups() -> void:
	for popup:PopupNotification in popups:
		popup.fade_out()
	
# Popup stacking
func _on_popup_completed_lifetime(popup: PopupNotification) -> void:
	popups.erase(popup)
	#print_debug("Active popups: ", popups.size())
#endregion
