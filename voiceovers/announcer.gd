class_name Announcer extends Node

@onready var announcer_player:FadeOutAudioStreamPlayer = $AnnouncerSfx

## Indicates whether this is a snowy level that triggers an "Avalanche" sfx
@export var is_avalance_level:bool = false

@export var multi_kill_duration_threshold:float = 4.0
@export var announcement_queue_turn_delay:float = 0.5

## What fraction of max health max to trigger overkill announcement
@export var enemy_health_fraction_overkill_threshold = 0.1

## What multiplier of max health is weapon's max damage to trigger overkill announcement
@export var max_health_multipler_overkill_threshold = 1.5

var _game_level:GameLevel
var _player:Player
var _last_turn_player: TankController
var _kill_count:int = 0
var _first_kill_time:float = 0.0
var _num_opponents:int
var _last_enemy_damage:float 

var _queued_announcements:Array[StringName] = []

# Destroy all opposing units on map with one shot
const annilation_sfx_res:StringName =  &"res://voiceovers/annihilation.mp3"

# Collapse terrain on a snowy mountain map that leads to damage to one or more players
# Trigger via an export bool when terrain chunk splits (Can listen for signal on the terrain on game level)
const avalanche_sfx_res:StringName = &"res://voiceovers/avalanche.mp3"

#You or an opponnent loses at least 50% of max health from fall damage without dying
const free_falling_sfx_res:StringName = &"res://voiceovers/free-fallin.mp3"

#Kill an opponent entirely from fall damage
const gravity_kill_sfx_res:StringName = &"res://voiceovers/gravity-kill.mp3"

# Kill multiple opponent with one shot
const multi_kill_sfx_res:StringName = &"res://voiceovers/multi-kill.mp3"
const overkill_sfx_res:StringName = &"res://voiceovers/overkill.mp3"
const sniper_shot_sfx_res:StringName = &"res://voiceovers/sniper-shot.mp3"
const trick_shot_sfx_res:StringName = &"res://voiceovers/trick-shot.mp3"
# You destroy 3 or more buildings or trees on the map
# Listen for damageable objects or destructible objects that emit destroyed events
# TODO: Will need to have all damageable object emit events - like the house, right now it is just tank
# Adding a node class to the "Damageable" group can act like an interface where we expect certain signals to be defined to
# just like the "take_damage" function is expected to exist on the class
# Alternatively, could emit this signal from the signal bus GameEvents class
const vandal_sfx_res:StringName = &"res://voiceovers/vandal.mp3"

# Knock artillery unit into water and kill it from hazard damage
const water_kill_sfx_res:StringName = &"res://voiceovers/water-kill.mp3"
# You accidentally take yourself out with your own shot
const whoopsies_sfx_res:StringName = &"res://voiceovers/whoopsies.mp3"

func _ready() -> void:
	GameEvents.level_loaded.connect(_on_level_loaded)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.player_added.connect(_on_player_added)
	GameEvents.turn_started.connect(_on_turn_started)
	GameEvents.turn_ended.connect(_on_turn_ended)
	
	announcer_player.priority_dictionary[whoopsies_sfx_res] = 100
	announcer_player.priority_dictionary[annilation_sfx_res] = 50
	announcer_player.priority_dictionary[multi_kill_sfx_res] = 40
	announcer_player.priority_dictionary[water_kill_sfx_res] = 30
	announcer_player.priority_dictionary[gravity_kill_sfx_res] = 20
	announcer_player.priority_dictionary[overkill_sfx_res] = 10

func _on_level_loaded(level: GameLevel) -> void:
	_game_level = level
	print_debug("%s: Level loaded - name=%s" % [name, _game_level.level_name])

func _on_round_started() -> void:
	# This is called AFTER all players added
	print_debug("%s: Round Started - level=%s" % [name, _game_level.level_name])
	_num_opponents = _game_level.round_director.tank_controllers.size() - 1
	
func _on_round_ended() -> void:
	print_debug("%s: Round ended -  level=%s" % [name, _game_level.level_name])
	
	_game_level = null
	_player = null
	_last_turn_player = null

func _on_player_added(player:TankController) -> void:
	if player is Player:
		_player = player
		player.tank.tank_killed.connect(_on_player_killed)
		player.tank.tank_took_damage.connect(_on_player_took_damage)
	else:
		player.tank.tank_took_damage.connect(_on_enemy_took_damage)
		player.tank.tank_killed.connect(_on_tank_killed)
		
	player.tank.tank_started_falling.connect(_on_tank_started_falling)
	player.tank.tank_stopped_falling.connect(_on_tank_stopped_falling)

func _on_player_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D) -> void:
	if instigatorController == _player:
		print_debug("%s: Player blew themselves up" % [name])
		announcer_player.switch_stream_res_and_play(whoopsies_sfx_res)	
		
func _on_tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D) -> void:

	# See if this is a water kill by player
	if _last_turn_player == _player and instigator is WaterHazard:
		print_debug("%s: Player water-killed %s" % [name, tank.get_parent()])
		announcer_player.switch_stream_res_and_play(water_kill_sfx_res)
	
	# Start clock for multi-kill
	var now:float = _game_level.game_timer.time_seconds
	
	if instigatorController != _player:
		return
		
	if _kill_count == 0 or (_last_turn_player != _player and now - _first_kill_time > multi_kill_duration_threshold):
		_kill_count = 0
		_first_kill_time = now
	_kill_count += 1
	
	if _kill_count >= 3 and _kill_count == _num_opponents:
		print_debug("%s: Annihilated all %d opponents!" % [name, _num_opponents])
		_queued_announcements.push_back(annilation_sfx_res)
	elif _kill_count == 2:
		print_debug("%s: Player triggered multi-kill" % [name])
		_queued_announcements.push_back(multi_kill_sfx_res)
	elif instigator is WeaponProjectile:
		# Check for overkill
		var damage_pct:float = _last_enemy_damage / tank.max_health
		var projectile:WeaponProjectile = instigator as WeaponProjectile
		var max_damage_to_max_health:float = projectile.max_damage  / tank.max_health
		if damage_pct <= enemy_health_fraction_overkill_threshold and max_damage_to_max_health >= max_damage_to_max_health:
			print_debug("%s: Player triggered overkill with %s on %s" % [name, projectile.source_weapon.display_name, tank.get_parent()])
			_queued_announcements.push_back(overkill_sfx_res)

func _on_turn_ended(player: TankController) -> void:
	await get_tree().create_timer(announcement_queue_turn_delay)
	_trigger_queued_announcement()
	
func _trigger_queued_announcement() -> void:
	print_debug("%s: Trigger queued announcements: %d" % [name, _queued_announcements.size()])
	# Trigger highest priority sound
	_queued_announcements.sort_custom(
		func(a:StringName, b:StringName) -> bool:
			return announcer_player.priority_dictionary.get(a, -1) > announcer_player.priority_dictionary.get(b, -1)
	)
	
	if !_queued_announcements.is_empty():
		announcer_player.switch_stream_res_and_play(_queued_announcements.front())
		_queued_announcements.clear()
	
func _on_player_took_damage(_tank: Tank, instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
		pass
		
func _on_enemy_took_damage(_tank: Tank, instigatorController: Node2D, _instigator: Node2D, amount: float) -> void:
	# Make sure player was instigator
	if instigatorController != _player:
		print_debug("%s: Ignore enemy took damage as wasn't by player - instigator=%s" % [name, instigatorController.name])	
		return
		
	print_debug("%s: Enemy took damage by player - enemy=%s; amount=%f" % [name, _tank.get_parent().name, amount])	
	_last_enemy_damage = amount 
	
func _on_turn_started(player: TankController) -> void:
	print_debug("%s: Player turn started" % [name])
	_last_turn_player = player
	if player == _player:
		_kill_count = 0

func _on_tank_started_falling(tank: Tank) -> void:
	pass
func _on_tank_stopped_falling(tank: Tank) -> void:
	pass
# TODO: Listen for event for building/destructible object damage done
