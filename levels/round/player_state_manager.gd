## Keeps track of player state between rounds and establishes this state at the start of the round
## TODO: Could use this as basis for data to auto-save/load player state from file
extends Node

## Toggles whether player state tracking should be enabled
## If disabled then each round will be independent of the others
var enable:bool:
	set(value):
		enable = value
		if value:
			print_debug("enable")
			_connect_events()
		else:
			print_debug("disable")
			_disconnect_events()
	get:
		return enable

var player: Player
var player_state: PlayerState
	
func _connect_events() -> void:
	if not GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.connect(_on_round_started)
	if not GameEvents.player_added.is_connected(_on_player_added):
		GameEvents.player_added.connect(_on_player_added)
	if not GameEvents.round_ended.is_connected(_on_round_ended):
		GameEvents.round_ended.connect(_on_round_ended)
	
func _disconnect_events() -> void:
	if GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.disconnect(_on_round_started)
	if GameEvents.player_added.is_connected(_on_player_added):
		GameEvents.player_added.disconnect(_on_player_added)

	if is_instance_valid(player):
		if player.tank.tank_killed.is_connected(_on_player_killed):
			player.tank.tank_killed.disconnect(_on_player_killed)
		if not player.get_parent():
			# This means that duplicate/removed child node was never added to tree so we need to manually free
			player.queue_free()
		player = null
		
func _on_round_started() -> void:
	pass

func _on_player_added(p_player: TankController) -> void:
	# Called before player added to the tree
	if p_player is not Player:
		return
	player = p_player

	player.tank.tank_killed.connect(_on_player_killed)
	if not player_state:
		print_debug("%s - no player state, skipping" % [name])
		return
	
	player.pending_state = player_state
	
func _on_round_ended() -> void:
	if not player:
		return
	# Capture the state of the player at the end of the round
	# Retain any previously unlocked weapons
	player_state = player.create_player_state().include_unlocks_from(player_state)

	# Will become invalid when the instance is destroyed by the current SceneTree
	player = null
	
func _on_player_killed(_tank: Tank, _instigatorController: Node2D, _instigator: Node2D) -> void:
	# TODO: Temporarily while we figure out the rogue-like mechanics
	pass

#region Savable

func restore_from_save_state(save: SaveState) -> void:
	if not enable:
		player_state = null
		return
	if SaveStateManager.consume_state_flag(SceneManager.new_story_selected, &"player"):
		PlayerState.delete_save_state(save)
		player_state = null
		return
		
	player_state = PlayerState.deserialize_from_save_state(save)
	print_debug("%s: restore_from_save_state: %s" % [name, is_instance_valid(player_state)])

func update_save_state(game_state:SaveState) -> void:
	if not enable or not player_state:
		return
	player_state.serialize_save_state(game_state)
	print_debug("%s: update_save_state" % name)
#endregion
