class_name Announcer extends Node

@onready var announcer_player:FadeOutAudioStreamPlayer = $AnnouncerSfx

## Indicates whether this is a snowy level that triggers an "Avalanche" sfx
@export var is_avalance_level:bool = false
@export var avalanche_area_threshold:float = 500.0

@export var multi_kill_duration_threshold:float = 4.0
@export var announcement_queue_turn_delay:float = 0.5

## What fraction of max health max to trigger overkill announcement
@export var enemy_health_fraction_overkill_threshold = 0.1

## What multiplier of max health is weapon's max damage to trigger overkill announcement
@export var max_health_multipler_overkill_threshold = 1.5

@export_range(0, 100, 1, "or_greater") var vandal_object_destroyed_threshold:int = 3

## Minimum fraction of health to lose from fall damage to trigger "Free-Fallin' announcement
@export var free_fallin_health_fraction_loss_threshold = 0.5

@export_range(0.0, 1.0, 0.05) var sniper_shot_bounds_dist_threshold = 0.75
@export_range(1.0, 3.0, 0.1) var direct_shot_bounds_multiplier = 1.5

var _game_level:GameLevel
var _player:Player
var _last_turn_player: TankController
var _kill_count:int = 0
var _first_kill_time:float = 0.0
var _num_opponents:int
var _last_enemy_damage:float 

class StampedAnnouncement:
	var res:StringName
	var game_time:float

enum SpecialShotType {
	TRICK_SHOT,
	SNIPER_SHOT
}

var _stamped_announcements:Array[StampedAnnouncement] = []
var _queued_announcements:Array[StringName] = []

var _objects_vandalized_by_player:Dictionary[int,bool] = {}
var _falling_players:Dictionary[int,float] = {}

# Only make special shot announcements once per enemy hit
var _special_shot_recorded_enemies:Dictionary[SpecialShotType, PackedInt32Array] = {
	SpecialShotType.TRICK_SHOT: PackedInt32Array(),
	SpecialShotType.SNIPER_SHOT: PackedInt32Array()
}


var _player_wall_interactions:Dictionary[Walls.WallInteractionLocation, int]

var _terrain_break_frame:int = -1

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
	GameEvents.took_damage.connect(_on_object_took_damage)
	GameEvents.wall_interaction.connect(_on_wall_interaction)
	
	announcer_player.priority_dictionary[whoopsies_sfx_res] = 100
	announcer_player.priority_dictionary[annilation_sfx_res] = 50
	announcer_player.priority_dictionary[multi_kill_sfx_res] = 40
	announcer_player.priority_dictionary[water_kill_sfx_res] = 30
	announcer_player.priority_dictionary[gravity_kill_sfx_res] = 20
	announcer_player.priority_dictionary[overkill_sfx_res] = 10

func _process(_delta: float) -> void:
	_check_stamped_announcements()
	
func _on_level_loaded(level: GameLevel) -> void:
	_game_level = level
	print_debug("%s: Level loaded - name=%s" % [name, _game_level.level_name])

func _on_round_started() -> void:
	# This is called AFTER all players added
	print_debug("%s: Round Started - level=%s" % [name, _game_level.level_name])
	_num_opponents = _game_level.round_director.tank_controllers.size() - 1
	
	if is_avalance_level:
		print_debug("%s - subscribing to terrain fracture events for avalanche level" % name)
		_game_level.terrain.chunk_split.connect(_on_terrain_chunk_split)

func _on_terrain_chunk_split(chunk: Node2D,  new_chunk: Node2D) -> void:
	# Only record when chunk splits off of the main chunk which will be of type TerrainChunk
	var notify:bool = chunk is TerrainChunk and new_chunk.has_method("get_area") and new_chunk.get_area() >= avalanche_area_threshold
	
	print_debug("%s: Terrain Chunk split: notify=%s; chunk=%s; new_chunk=%s" % [name, notify, chunk, new_chunk])

	if notify:
		_terrain_break_frame = _game_level.game_timer.frame
	
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

func _on_player_killed(_tank: Tank, instigatorController: Node2D, _instigator: Node2D) -> void:
	if instigatorController == _player:
		print_debug("%s: Player blew themselves up" % [name])
		announcer_player.switch_stream_res_and_play(whoopsies_sfx_res)	
		
func _on_tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D) -> void:
	# See if this is a water kill by player
	if _last_turn_player == _player and instigator is WaterHazard:
		print_debug("%s: Player water-killed %s" % [name, tank.owner])
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
		if damage_pct <= enemy_health_fraction_overkill_threshold and max_damage_to_max_health >= max_health_multipler_overkill_threshold:
			print_debug("%s: Player triggered overkill with %s on %s" % [name, projectile.source_weapon.display_name, tank.owner])
			_queued_announcements.push_back(overkill_sfx_res)

func _on_turn_ended(__player: TankController) -> void:
	await get_tree().create_timer(announcement_queue_turn_delay).timeout
	_trigger_queued_announcement()

#region Announcement Batching

func _trigger_queued_announcement() -> void:
	print_debug("%s: Trigger queued announcements: %d" % [name, _queued_announcements.size()])
	_trigger_highest_priority_sfx(_queued_announcements)

func _check_stamped_announcements() -> void:
	if _stamped_announcements.is_empty() or not is_instance_valid(_game_level):
		return
		
	var current_time:float = _game_level.game_timer.time_seconds
	var annoucements:Array[StringName] = []
	
	# Determine ones meeting criteria
	for i in range(_stamped_announcements.size() - 1, -1, -1):
		var stamped_announcement:StampedAnnouncement = _stamped_announcements[i]
		if stamped_announcement.game_time >= current_time:
			annoucements.push_back(stamped_announcement.res)
			_stamped_announcements.erase(stamped_announcement)
	
	_trigger_highest_priority_sfx(annoucements)
	
	print_debug("%s: %d stamped announcements remain" % [name, _stamped_announcements.size()])
	
func _add_stamped_announcement(resource:StringName, delta_time: float) -> void:
		var game_timer:GameTimer = _game_level.game_timer
		var annoucement := StampedAnnouncement.new()
		annoucement.res = resource
		annoucement.game_time = game_timer.time_seconds + delta_time
		
		_stamped_announcements.push_back(annoucement)
		
func _trigger_highest_priority_sfx(announcements: Array[StringName]) -> void:
	announcements.sort_custom(
		func(a:StringName, b:StringName) -> bool:
			return announcer_player.priority_dictionary.get(a, -1) > announcer_player.priority_dictionary.get(b, -1)
	)
	
	if !announcements.is_empty():
		announcer_player.switch_stream_res_and_play(announcements.front())
		announcements.clear()

#endregion

func _on_player_took_damage(tank: Tank, instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	_check_gravity_damage_announce(tank, instigatorController, instigator, amount)
		
func _on_enemy_took_damage(tank: Tank, instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	if instigatorController == _player and tank != instigator:
		print_debug("%s: Enemy took damage by player - enemy=%s; amount=%f" % [name, tank.owner, amount])	
		_last_enemy_damage = amount
		
		_check_for_trick_shot(tank, instigator)
		_check_for_sniper_shot(tank, instigator)
	else:
		_check_gravity_damage_announce(tank, instigatorController, instigator, amount)
		
func _on_turn_started(player: TankController) -> void:
	print_debug("%s: Player turn started" % [name])
	_last_turn_player = player
	if player == _player:
		_kill_count = 0
		_player_wall_interactions.clear()
	
	# clear any existing avalanche frame counters
	_terrain_break_frame = -1
	
#region Vandalism

func _on_object_took_damage(object: Node, instigatorController: Node2D, _instigator: Node2D, _contact_point: Vector2, _damage: float) -> void:
	print_debug("%s: Object took damage - name=%s" % [name, object.name])
	
	# Ignore things not damaged by player
	if instigatorController != _player:
		return
		
	# Get the damageable root - exclude terrain and tank
	var object_root:Node = Groups.get_parent_in_group(object, Groups.DamageableRoot)
	if not object_root or object_root is Tank or object_root is Terrain or Groups.get_parent_in_group(object, Groups.TerrainChunk):
		return

	var object_id:int = object_root.get_instance_id()
	if object_id in _objects_vandalized_by_player:
		print_debug("%s: Player already vandalized %s" % [name, object_root.name])
		return
		
	_objects_vandalized_by_player[object_id] = true
	print_debug("%s: Player vandalized %s" % [name, object_root.name])
	print_debug("%s: Player vandalized %d objects" % [name, _objects_vandalized_by_player.size()])

	if _objects_vandalized_by_player.size() == vandal_object_destroyed_threshold:
		print_debug("%s: Triggering vandal announcement - Player vandalized %d objects" % [name, _objects_vandalized_by_player.size()])
		_queued_announcements.push_back(vandal_sfx_res)

#endregion

#region Fall Damage

func _on_tank_started_falling(tank: Tank) -> void:
	var controller:TankController = tank.owner
	if controller:
		print_debug("%s - %s started falling" % [name, controller.name])
		_falling_players[controller.get_instance_id()] = tank.health
		
		# Check for avalanche announcement
		if _terrain_break_frame >= 0:
			_add_stamped_announcement(avalanche_sfx_res, 0.1)
			_terrain_break_frame = -1
		
func _on_tank_stopped_falling(tank: Tank) -> void:
	var controller:TankController = tank.owner
	if controller:
		print_debug("%s - %s stopped falling" % [name, controller.name])
		# This doesn't trigger until after the damage event so we can use the data stored to check for amount
		_falling_players.erase(controller.get_instance_id())

func _check_gravity_damage_announce(tank: Tank, _instigator_controller: Node2D, instigator: Node2D, amount: float) -> void:
	# For gravity damage the instigatorController is self and instigator is tank itself
	# TODO: Have a damage type and falling as this type or have a separate event to distinguish more reliably
	# For fall damage instigator will be the tank itself but the instigator_controller could be another player that caused the fall
	if instigator != tank or not tank.owner:
		return
		
	var instigator_id:int = tank.owner.get_instance_id()
	if not instigator_id in _falling_players:
		print_debug("%s - _check_gravity_damage_announce - false positive on %s as wasn't in the falling dictionary" % [name,  tank.owner])
		return
	
	var starting_health:float = _falling_players[instigator_id]
	var is_kill:bool = is_equal_approx(amount, starting_health)
	
	if is_kill:
		print_debug("%s - _check_gravity_damage_announce: player %s killed by gravity alone" % [name,  tank.owner])
		#_queued_announcements.push_back(gravity_kill_sfx_res)
		_add_stamped_announcement(gravity_kill_sfx_res, 0.1)
	else:
		var loss_fraction:float = amount / tank.max_health
		var trigger_damage_alert:bool = loss_fraction >= free_fallin_health_fraction_loss_threshold
	
		print_debug("%s - _check_gravity_damage_announce: player=%s; amount=%f; loss_fraction=%f; trigger=%s" % [name,  tank.owner, amount, loss_fraction, trigger_damage_alert])
	
		if trigger_damage_alert:
			#_queued_announcements.push_back(free_falling_sfx_res)
			_add_stamped_announcement(free_falling_sfx_res, 0.1)
		
#endregion

#region Wall Interactions
func _on_wall_interaction(_walls: Walls, projectile: WeaponProjectile, interaction_location: Walls.WallInteractionLocation) -> void:
	if not is_instance_valid(projectile.owner_tank) or not is_instance_valid(projectile.owner_tank.owner):
		return
	var player:TankController = projectile.owner_tank.owner
	if player != _player:
		return
	
	var count:int = _player_wall_interactions.get(interaction_location, 0)
	count += 1
	_player_wall_interactions[interaction_location] = count
	
	print_debug("%s - recording player wall interaction: %s -> %d; %d total unique interactions" % [name, interaction_location, count, _player_wall_interactions.size()])

#endregion

func _is_direct_shot(enemy: Tank, instigator: Node2D) -> bool:
	var projectile:WeaponProjectile = instigator as WeaponProjectile
	if not projectile:
		return false
	
	# Make sure it was a direct hit
	var bounds:Rect2 = Rect2(
		Vector2(enemy.left_reference_point.global_position.x, enemy.top_reference_point.global_position.y),
		Vector2(enemy.right_reference_point.global_position.x - enemy.left_reference_point.global_position.x,
				enemy.bottom_reference_point.global_position.y - enemy.top_reference_point.global_position.y)
	)
	
	# Expand the bounds for leniency
	var size:Vector2 = bounds.size
	var grow_side_amount:Vector2 = size * direct_shot_bounds_multiplier * 0.5
	
	bounds = bounds.grow_individual(grow_side_amount.x, grow_side_amount.y, grow_side_amount.x, grow_side_amount.y)
		
	return bounds.has_point(projectile.global_position)
	
#region Trick Shot

func _check_for_trick_shot(enemy: Tank, instigator: Node2D) -> void:
	if _player_wall_interactions.size() < 2 or not is_instance_valid(_player) \
	 or enemy.get_instance_id() in _special_shot_recorded_enemies[SpecialShotType.TRICK_SHOT] \
	 or not _is_direct_shot(enemy, instigator):
		return
	
	# Check for LOS
	var space_state := _player.get_world_2d().direct_space_state

	var start_pos:Vector2 = _player.tank.top_reference_point.global_position
	var end_pos:Vector2 = enemy.top_reference_point.global_position
	
	var query_params := PhysicsRayQueryParameters2D.create(
		start_pos, end_pos,
		Collisions.CompositeMasks.obstacle)

	var result: Dictionary = space_state.intersect_ray(query_params)
	
	# Have line of sight
	if not result:
		print_debug("%s - trick shot on %s" % [name, enemy.owner])

		_special_shot_recorded_enemies[SpecialShotType.TRICK_SHOT].push_back(enemy.get_instance_id())
		_queued_announcements.push_back(trick_shot_sfx_res)
#endregion

#region Sniper Shot
func _check_for_sniper_shot(enemy: Tank, instigator: Node2D) -> void:
	if not _player_wall_interactions.is_empty() or not is_instance_valid(_player) \
	 or enemy.get_instance_id() in _special_shot_recorded_enemies[SpecialShotType.SNIPER_SHOT] \
	 or not _is_direct_shot(enemy, instigator):
		return

	# Determine x distance
	var dist_x:float = absf(_player.tank.global_position.x - enemy.global_position.x)
	var level_bounds_x:float = _game_level.walls.bounds.size.x
	var dist_fraction:float = dist_x / level_bounds_x
	var is_sniper_shot:bool = dist_fraction >= sniper_shot_bounds_dist_threshold
	
	print_debug("%s - sniper_shot on %s: dist_x=%f; fraction=%f; is_sniper_shot=%s" % [name, enemy.owner, dist_x, dist_fraction, is_sniper_shot])
	
	if is_sniper_shot:
		print_debug("%s - sniper shot on %s" % [name, enemy.owner])
		_special_shot_recorded_enemies[SpecialShotType.SNIPER_SHOT].push_back(enemy.get_instance_id())
		_queued_announcements.push_back(sniper_shot_sfx_res)
#endregion
