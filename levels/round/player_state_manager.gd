extends Node

var enable:bool:
	set(value):
		if value:
			print_debug("%s: enable" % [name])
			_connect_events()
		else:
			print_debug("%s: disable" % [name])
			_disconnect_events()
	get:
		return enable

var player: Player
var player_name: StringName
	
func _connect_events() -> void:
	if not GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.connect(_on_round_started)
	if not GameEvents.player_added.is_connected(_on_player_added):
		GameEvents.player_added.connect(_on_player_added)
	if not GameEvents.round_ended.is_connected(_on_round_ended):
		GameEvents.round_ended.connect(_on_round_ended)
	
func _disconnect_events() -> void:
	if  GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.disconnect(_on_round_started)
	if is_instance_valid(player):
		if player.tank.tank_killed.is_connected(_on_player_killed):
			player.tank.tank_killed.disconnect(_on_player_killed)
		if not player.get_parent():
			# This means that duplicate was never added to tree so we need to manually free
			player.queue_free()
		player = null
		
func _on_round_started() -> void:
	pass
	#if is_instance_valid(player):
		#_replace_player_reference()
	#else:
		#var level:GameLevel = SceneManager.get_current_level_root()
		#player = level.round_director.player
		#if player:
			#player.tank.tank_killed.connect(_on_player_killed)

func _on_player_added(p_player: TankController) -> void:
	if p_player is not Player:
		return
	if is_instance_valid(player):
		_replace_player_reference()
	else:
		#var level:GameLevel = SceneManager.get_current_level_root()
		#player = level.round_director.player
		#if player:
		player = p_player
		player.tank.tank_killed.connect(_on_player_killed)
	
func _on_round_ended() -> void:
	# Make a copy of player before it is freed
	if not player:
		return
	
	# Duplicate so not lost when round director frees
	# Will be added to the tree on next round
	# This doesn't work
	#var orig_name := player.name
	# #player = player.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
	#player = player.duplicate()
	#player.name = orig_name
	
	# Instead of duplicating just remove from the tree so it doesn't get freed
	player_name = player.name

	var parent := player.get_parent()
	if parent:
		parent.remove_child(player)
	
func _on_player_killed(_tank: Tank, _instigatorController: Node2D, _instigator: Node2D) -> void:
	# TODO: Temporarily while we figure out the rogue-like mechanics
	player = null
	
func _replace_player_reference() -> void:
	print_debug("%s - replace player reference to %s" % [name, player.name])
	var level:GameLevel = SceneManager.get_current_level_root()
	level.round_director.player = player
	# Need to re-request since was already added to tree so weapons set up right
	player.request_ready()
	player.name = player_name
