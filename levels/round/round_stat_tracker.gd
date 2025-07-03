extends Node

## Keep track of enemy damage to award scrap with different amounts when level complete
class EnemyData:
	var name:String
	# Player caused some damage to the opponent
	var damaged_by_player:bool
	# Another opponent other than the AI itself caused the damage
	var damaged_by_nonplayer:bool
	# Player was instigator for the kill
	var killed_by_player:bool
	var last_damager:int

	func set_name(tank: Tank) -> void:
		name = tank.get_parent().to_string() if tank.get_parent() else str(tank.name)
		
	func is_full_kill() -> bool:
		return killed_by_player and not damaged_by_nonplayer
	
	func is_partial_kill() -> bool:
		return killed_by_player and damaged_by_nonplayer
	
	func is_damaged() -> bool:
		return damaged_by_player


class RoundData:
	var start_health:float
	var final_health:float
	var max_health:float
	# Ideally health_lost should be max_health - final_health unless player takes damage before level starts
	# which should only be happening in test levels where fall_damage before start isn't configured right
	var health_lost:float
	var damage_done:float
	var kills:int
	var turns:int
	var game_time:float
	var died:bool
	var won:bool
	var level_name:String

	var enemies_damaged:Dictionary[int, EnemyData]
	var total_enemies:int
	
	# Additional rewards based on groups + metadata when objects destroyed
	var additional_scrap_rewarded:int
	var additional_personnel_rewarded:int
	
var round_data:RoundData 
var _player:Player
var _current_level:GameLevel
var _rewarded_objects:Dictionary[int, bool] = {}

func _ready() -> void:
	round_data = RoundData.new() #Simplify null reference checks
	
	GameEvents.level_loaded.connect(_on_level_loaded)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.player_added.connect(_on_player_added)
	GameEvents.turn_started.connect(_on_turn_started)
	
	GameEvents.took_damage.connect(_on_object_took_damage)
	
@warning_ignore_start("unused_parameter")
func _on_level_loaded(level: GameLevel) -> void:
	_current_level = level
	_rewarded_objects.clear()

	round_data = RoundData.new()
	print_debug("%s: Level loaded - (name=%s)" % [name, _current_level.level_name])	

func _on_round_started() -> void:
	# This is called AFTER all players added
	if is_instance_valid(_player):
		round_data.max_health = _player.tank.max_health
		round_data.start_health = _player.tank.health
	round_data.level_name = _current_level.name
	print_debug("%s: Round Started - (level=%s)" % [name, round_data.level_name])	

func _on_round_ended() -> void:
	if not _player:
		return
		
	if not round_data.died:
		round_data.won = true
		round_data.final_health = _player.tank.health
		
	# Will get destroyed so invalidate references
	_player = null
	_current_level = null
	
	print_debug("%s: Round ended - (won=%s)" % [name, round_data.won])	
	
func _on_player_died(player:TankController) -> void:
	if player is Player:
		print_debug("%s: Player died" % [name])	
		round_data.died = true
		
func _on_player_added(player:TankController) -> void:
	if player is Player:
		_player = player
		player.tank.tank_took_damage.connect(_on_player_took_damage)
	else:
		round_data.total_enemies += 1
		player.tank.tank_took_damage.connect(_on_enemy_took_damage)
		player.tank.tank_killed.connect(_on_tank_killed)

func _on_tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D) -> void:
	var enemy_data:EnemyData = get_or_add_enemy_data(tank)
	enemy_data.set_name(tank)
	
	# Additionally credit player with kill if they did some damage to opponent but opponent credited with killing themselves
	var instigator_was_player:bool = instigatorController and _player and (instigatorController == _player or \
	 (instigatorController == tank.get_parent() and enemy_data.last_damager == _player.get_instance_id()))
	enemy_data.killed_by_player = instigator_was_player

	if not instigator_was_player:
		print_debug("%s: Ignore %s killed %s" % [name, instigatorController.name if instigatorController else &"", tank.get_parent()])	
		return
		
	round_data.kills += 1
	print_debug("%s: Player killed %s (kills=%d)" % [name, tank.get_parent(), round_data.kills])	
	
func _on_player_took_damage(_tank: Tank, instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
	round_data.health_lost += amount
	print_debug("%s: Player took damage: %f (health_lost=%f)" % [name, amount, round_data.health_lost])

func _on_enemy_took_damage(tank: Tank, instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
	var enemy_data:EnemyData = get_or_add_enemy_data(tank)
	enemy_data.set_name(tank)
	if instigatorController and instigatorController == _player:
		enemy_data.damaged_by_player = true
		enemy_data.last_damager = instigatorController.get_instance_id()
	elif instigatorController and instigatorController != tank.get_parent():
		# Damaged by another AI - don't count self damage against player for points calculation
		enemy_data.damaged_by_nonplayer = true
		enemy_data.last_damager = instigatorController.get_instance_id()
		print_debug("%s: Enemy %s took damage by %s" % [name, tank.get_parent(), instigatorController.name])

	# Make sure player was instigator
	if instigatorController != _player:
		var _name:String
		if is_instance_valid(instigatorController):
			if "name" in instigatorController:
				_name = instigatorController.name
			else:
				_name = instigatorController.to_string()
		else:
			_name = "Nil"
		print_debug("%s: Ignore enemy %s took damage amount as wasn't by player - instigator=%s" % [name, tank.get_parent(), _name])
		return
		
	round_data.damage_done += amount
	print_debug("%s: Enemy %s took damage by player - amount=%f (damage_done=%f)" % [name, tank.get_parent(), amount, round_data.damage_done])	

func get_or_add_enemy_data(tank: Tank) -> EnemyData:
	var key:int = tank.get_instance_id()
	var enemy_data:EnemyData = round_data.enemies_damaged.get(key)
	if not enemy_data:
		enemy_data = EnemyData.new()
		round_data.enemies_damaged.set(key, enemy_data)
	return enemy_data
	
func _on_turn_started(player: TankController) -> void:
	if player != _player:
		print_debug("%s: Ignore non-player start - player=%s" % [name, player.name])	
		return
	round_data.turns += 1
	print_debug("%s: Player turn started (turns=%d)" % [name, round_data.turns])

func _on_object_took_damage(object: Node, instigatorController: Node2D, instigator: Node2D, contact_point: Vector2, damage: float) -> void:
	if not object.is_in_group(Groups.RewardableOnDestroy):
		return
	# Make sure took damage from live player
	if not instigatorController or not _player or instigatorController != _player:
		return

	# Check that health is zero
	if not "health" in object:
		push_warning("%s: Ignore took damage on %s as no health property available" % [name, object.name])
		return

	var health:float = float(object.health)
	if not is_zero_approx(health):
		return
	
	var object_id:int = object.get_instance_id()
	if object_id in _rewarded_objects:
		print_debug("%s: Ignore %s destroyed as already rewarded" % [name, object.name])
		return
	
	if object.has_meta(Groups.RewardOnDestroyDetails.RewardTypeKey) and object.has_meta(Groups.RewardOnDestroyDetails.RewardAmountKey):
		var reward_type:String = object.get_meta(Groups.RewardOnDestroyDetails.RewardTypeKey)
		if reward_type.nocasecmp_to(Groups.RewardOnDestroyDetails.Scrap) == 0:
			var scrap_amount:int = int(object.get_meta(Groups.RewardOnDestroyDetails.RewardAmountKey))
			round_data.additional_scrap_rewarded += scrap_amount
			print_debug("%s: Rewarded %d scrap for %s" % [name, scrap_amount, object.name])
		elif reward_type.nocasecmp_to(Groups.RewardOnDestroyDetails.Personnel) == 0:
			var personnel_amount:int = int(object.get_meta(Groups.RewardOnDestroyDetails.RewardAmountKey))
			round_data.additional_personnel_rewarded += personnel_amount
			print_debug("%s: Rewarded %d personnel for %s" % [name, personnel_amount, object.name])
		else:
			push_warning("%s: Unknown reward type '%s' for %s" % [name, reward_type, object.name])
			return
	else:
		push_warning("%s: No reward type and/or reward amount key defined for %s" % [name, object.name])
		return

	_rewarded_objects[object_id] = true
