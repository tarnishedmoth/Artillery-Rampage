class_name RoundDirector extends Node

var tank_controllers: Array = []
var active_player_index: int = -1

var turns_since_damage: int = 0

@export
var lightning_time: int = 3

@export
var lightning_strength: float = 25.0

@export 
var physics_check_time: float = 0.25

@export
var max_fall_check_time:float = 20.0

var fall_check_timer: Timer

signal tanks_stopped_falling

var _fall_check_elapsed_time:float = 0.0

var current_gamestate: GameState
@export var is_simultaneous_fire: bool = false
var awaiting_intentions:int = 0

## Set whether player always goes first in round 
@export var player_goes_first:bool = false

## Determine whether we shuffle the turn order or use the child order
## player_goes_first will be honored if set
@export var shuffle_order:bool = true

var directed_by_external_script:bool = false ## If true, the round does not end if only the Player is alive.
var _directed_by_external_script_condition:bool = false ## See [method end_round].

var player: Player:
	get:
		var index:int = _get_player_index()
		if index != -1:
			return tank_controllers[index]
		push_warning("%s - player not found!" % [name])
		return null
	set(value):
		# TODO: This setter is no longer being used but keeping in case it proves useful later
		if not value:
			return
		var index:int = _get_player_index()
		if index == -1:
			push_warning("%s - player not found!" % [name])
			return
		var existing:Player = tank_controllers[index]
		if value == existing:
			print_debug("%s - player=%s is already in the round" % [name, existing.name])
			return
		
		print_debug("%s - Changing player from %s to %s" % [name, existing.name, value.name])

		# retain transform
		var transform: Transform2D = existing.global_transform
		var previous_parent:Node = existing.get_parent()
				
		tank_controllers[index] = value		
		value.global_transform = transform
		
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(existing)
			previous_parent.add_child(value)
		else:
			push_warning("%s - player did not have previous parent - using this node" % [name, value.name])
			add_child(value)
		existing.queue_free()
		
func _ready():
	GameEvents.player_added.connect(_on_player_added)
	
	current_gamestate = create_new_gamestate() # TODO: loading saved gamestate
	
	fall_check_timer = Timer.new()
	fall_check_timer.set_wait_time(0.5)
	fall_check_timer.set_one_shot(false)
	fall_check_timer.connect("timeout", _on_fall_check_timeout)
	fall_check_timer.autostart = false
	
	add_child(fall_check_timer)
	
func _enter_tree() -> void:
	GameEvents.tank_changed.connect(_on_tank_changed)

func add_controller(tank_controller: TankController) -> void:
	if not tank_controller in tank_controllers:
		tank_controllers.append(tank_controller)
	
	for controller:TankController in tank_controllers:
		connect_controller(controller)
	
	GameEvents.player_added.emit(tank_controller)
	
func connect_controller(controller: TankController) -> void:
	if not controller.signals_connected:
		controller.tank.tank_killed.connect(_on_tank_killed)
		controller.intent_to_act.connect(_on_player_intent_to_act)
		controller.tank.tank_took_damage.connect(_on_tank_damage.unbind(4))
		controller.signals_connected = true
	
func _on_tank_changed(controller: TankController, _old_tank: Tank, new_tank: Tank) -> void:
	if controller in tank_controllers and controller.signals_connected:
		new_tank.tank_killed.connect(_on_tank_killed)
	
func _on_player_added(_controller:TankController) -> void:
	pass
	
func _on_fall_check_timeout():
	_fall_check_elapsed_time += fall_check_timer.wait_time
	
	if !is_any_tank_falling():
		print("_on_fall_check_timeout: Stopping fall_check_timer")
		_stop_fall_check_timer()
	elif _fall_check_elapsed_time >= max_fall_check_time:
		push_warning("_on_fall_check_timeout: Fall check timer exceeded max time of %fs - Force stopping the timer")
		_stop_fall_check_timer()
		
func _stop_fall_check_timer() -> void:
	fall_check_timer.stop()
	tanks_stopped_falling.emit()
	_fall_check_elapsed_time = 0.0
	
func begin_round() -> bool:
	GameEvents.turn_ended.connect(_on_turn_ended)
	
	for controller: TankController in tank_controllers:
		connect_controller(controller)
		
		controller.begin_round()
		
	set_turn_order()
	
	# Await at start in case tanks are falling at start
	# TODO: Maybe remove this before release
	await _async_check_and_await_falling()
	
	GameEvents.round_started.emit()
	
	#return next_player()

	# Await as next_turn is async
	return await next_turn()

#region Turn Order
func set_turn_order() -> void:
	if shuffle_order:
		print_debug("Shuffling turn order")
		tank_controllers.shuffle()
	if player_goes_first:
		print_debug("Setting player to go first")
		_swap_players(0, _get_player_index())
		
func _get_player_index() -> int:
	for i in range(tank_controllers.size()):
		if tank_controllers[i] is Player:
			return i
	return -1
	
func _swap_players(first_index: int, second_index: int) -> void:
	if first_index < 0 or first_index >= tank_controllers.size() or second_index < 0 or second_index >= tank_controllers.size():
		return
	
	var temp: TankController = tank_controllers[first_index]
	tank_controllers[first_index] = tank_controllers[second_index]
	tank_controllers[second_index] = temp

#endregion

func check_players() -> bool:
	# If there are 1 or 0 players left then the round is over
	if directed_by_external_script:
		# Allow for managed situations with only the Player left
		if not _directed_by_external_script_condition:
			for controller in tank_controllers:
				if controller is Player:
					# Player alive
					print_debug("Special Level: Player is alive. Check passed.")
					return true
			# Player dead
			print_debug("Special Level: Player not found. Check failed. \n", tank_controllers)
			return false
		else:
			# Managed condition is true
			return false
	if tank_controllers.size() <= 1:
		active_player_index = -1
		return false

	# if all remaining players on the same team then end the round as well
	var team: int = tank_controllers[0].team
	# team < 0 means no team so at least one valid target for the other player
	if team < 0:
		return true
	
	for i in range(1, tank_controllers.size()):
		if team != tank_controllers[i].team:
			return true
	# All players are on the same team
	return false
	
## This method is used by special levels with scripted behavior to allow for different gameplay.
## See Factory (level_special_factory.tscn).
func end_round() -> void:
	_directed_by_external_script_condition = true
		
#region Turn Based
func next_turn() -> bool:
	if not check_players(): return false
	awaiting_intentions = 0
	if not is_simultaneous_fire:
		await next_player() # Turn-based game
	else:
		# Simultaneous fire
		all_players()
		
	return true

func next_player() -> void:
	await get_tree().process_frame
	if turns_since_damage > lightning_time:
		trigger_lightning()
	active_player_index = (active_player_index + 1) % tank_controllers.size()
	var active_player = tank_controllers[active_player_index]
	if not is_instance_valid(active_player):
		active_player = tank_controllers.front()
		print_debug("Invalid active player, resetting to front of array.")
	
	print_debug("Turn beginning for %s" % [active_player.name])
	
	awaiting_intentions += active_player.actions_per_turn
	active_player.begin_turn()
	GameEvents.turn_started.emit(active_player)
	
func _on_turn_ended(controller: TankController) -> void:
	print("Turn ended for " + controller.name)
	turns_since_damage += 1
	print("Turns since damage: " + str(turns_since_damage))
	if awaiting_intentions > 0:
		print_debug("Turn ended but awaiting %s intentions from player" % [controller.name])
		return
	
	await _async_check_and_await_falling()
	
	var round_over:bool = not await next_turn()

	# See if orbit completed
	if active_player_index <= 0:
		print_debug("Orbit completed")
		GameEvents.orbit_cycled.emit()

	if round_over:
		GameEvents.round_ended.emit()
#endregion

func all_players() -> void:
	for instance:TankController in tank_controllers:
		print_debug("Turn beginning for %s" % [instance.name])
		awaiting_intentions += 1
		instance.begin_turn()
		
func execute_all_actions() -> void:
	var actions = current_gamestate.get_actions()
	var actions_taken: int = 0
	for i in actions.size():
		current_gamestate.run_next_action()
		actions_taken += 1
	print_debug("Executed",actions_taken,"actions.")

func _async_check_and_await_falling() -> void:
	 # Wait for physics to settle prior to allowing next player to start
	# or just make this class a Node and add to tree from Game
	var scene_tree := get_tree()

	# Wait a smidge and then check if any tank is falling and give time for physics to settle
	await scene_tree.create_timer(physics_check_time).timeout
	
	if is_any_tank_falling():
		print("_on_turn_ended: At least one tank falling - Starting fall_check_timer")
		fall_check_timer.start()
		await tanks_stopped_falling
		
func is_any_tank_falling() -> bool:
	for controller in tank_controllers:
		if is_instance_valid(controller) && controller.tank.is_falling():
			return true
	return false
	
func _on_tank_damage():
	turns_since_damage = 0
	
func _on_tank_killed(tank: Tank, _instigatorController: Node2D, _instigator: Node2D):
	# Need to reset the active player index when removing the controller
	var tank_controller_to_remove: TankController = tank.owner
	if !is_instance_valid(tank_controller_to_remove):
		push_warning("tank=" + tank.name + " has no owner controller")
		return
	var index_to_remove: int = tank_controllers.find(tank_controller_to_remove)
	if(index_to_remove < 0):
		push_warning("TankController=" + tank_controller_to_remove.name + " is not in round")
		return
	
	tank_controllers.remove_at(index_to_remove)
	
	# See if we need to shift the active player index
	if index_to_remove <= active_player_index:
		active_player_index -= 1
		if active_player_index < 0:
			active_player_index = tank_controllers.size() - 1

func _on_player_intent_to_act(action: Callable, apply_to: Object) -> void:
	print_debug("Received action: ",action,apply_to.name)
	current_gamestate.queue_action(action, apply_to)
	awaiting_intentions -= 1
	if awaiting_intentions < 1:
		execute_all_actions()
		
func trigger_lightning():
	turns_since_damage = 0
	var random_target = tank_controllers.pick_random()
	random_target.tank.take_damage(random_target, random_target.tank, lightning_strength)

#region Game State
func create_new_gamestate() -> GameState:
	return GameState.new()

class GameState extends Resource: # Resource supports save/load
	class Action:
		var action: Callable
		var caller: TankController
		# I just realized I recreated the Callable class but maybe we'll extend it
		
	var _action_queue:Array[Action]
	var actions_taken_count:int
	
	func run_action(action: Action) -> void:
		action.action.call()
		actions_taken_count += 1
		
	func run_next_action() -> void:
		pop_next_action().action.call_deferred()
		actions_taken_count += 1
	
	func queue_action(action: Callable, caller: TankController) -> void:
		var new_action = Action.new()
		new_action.action = action
		new_action.caller = caller
		_action_queue.append(new_action)
		
	func get_actions() -> Array[Action]:
		return _action_queue
	
	func get_next_action() -> Action:
		return _action_queue.front()
		
	func get_actions_by_owner(action_owner: TankController) -> Array[Action]:
		return _action_queue.filter(_check_action_owner.bind(action_owner))
	
	func erase_actions_by_owner(action_owner: TankController) -> void:
		_action_queue = _action_queue.filter(_check_action_owner.bind(action_owner, true))
		
	func pop_next_action() -> Action:
		return _action_queue.pop_front()
	
	func _check_action_owner(action: Action, check: TankController, invert:bool = false) -> bool:
		if action.caller == check: return true if not invert else false
		else: return false if not invert else true
	
#endregion
