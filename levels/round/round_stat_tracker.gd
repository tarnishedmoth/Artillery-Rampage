extends Node

class RoundData:
	var health_lost:float
	var damage_done:float
	var kills:int
	var turns:int
	var game_time:float
	var died:bool
	var won:bool
	var level_name:String
	
var round_data:RoundData 
var _player:Player
var _current_level:GameLevel

func _ready() -> void:
	round_data = RoundData.new() #Simplify null reference checks
	
	GameEvents.level_loaded.connect(_on_level_loaded)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.player_added.connect(_on_player_added)
	GameEvents.turn_started.connect(_on_turn_started)
	
func _on_level_loaded(level: GameLevel) -> void:
	_current_level = level
	print_debug("%s: Level loaded - (name=%s)" % [name, _current_level.level_name])	

func _on_round_started() -> void:
	round_data = RoundData.new()
	round_data.level_name = _current_level.name
	print_debug("%s: Round Started - (level=%s)" % [name, round_data.level_name])	

func _on_round_ended() -> void:
	if not round_data.died:
		round_data.won = true
		
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
		player.tank.tank_took_damage.connect(_on_enemy_took_damage)
		player.tank.tank_killed.connect(_on_tank_killed)

func _on_tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D) -> void:
	if instigatorController != _player:
		print_debug("%s: Ignore %s killed %s" % [name, instigatorController.name, tank.get_parent().name])	
		return
		
	round_data.kills += 1
	print_debug("%s: Player killed %s (kills=%d)" % [name, tank.get_parent().name, round_data.kills])	
	
func _on_player_took_damage(_tank: Tank, instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
	round_data.health_lost += amount
	print_debug("%s: Player took damage: %f (health_lost=%f)" % [name, amount, round_data.health_lost])

func _on_enemy_took_damage(_tank: Tank, instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
	# Make sure player was instigator
	if instigatorController != _player:
		print_debug("%s: Ignore enemy took damage as wasn't by player - instigator=%s" % [name, instigatorController.name])	
		return
		
	round_data.damage_done += amount
	print_debug("%s: Enemy took damage by player - enemy=%s; amount=%f (damage_done=%f)" % [name, _tank.get_parent().name, amount, round_data.damage_done])	

func _on_turn_started(player: TankController) -> void:
	if player != _player:
		print_debug("%s: Ignore non-player start - player=%s" % [name, player.name])	
		return
	round_data.turns += 1
	print_debug("%s: Player turn started (turns=%d)" % [name, round_data.turns])
	
# TODO: Listen for event for building/destructible object damage done
