extends Node

## UI sound effects.
## Should handle things that are not positional in nature,
## like round end, turn change, game over...

@export var soundtrack_file: AudioStream

@export_group("AudioStreamPlayers","sfx_")
@export var sfx_round_started: AudioStreamPlayer
@export var sfx_round_ended: AudioStreamPlayer
@export var sfx_turn_started: AudioStreamPlayer
@export var sfx_turn_ended: AudioStreamPlayer
@export var sfx_weapon_updated: AudioStreamPlayer
@export var sfx_soundtrack: AudioStreamPlayer

var initial_db_values:Dictionary
var _sfx_volume_modifier:float = 1.0 ## This needs to be with other Options in a singleton so it can be requested.
var _music_volume_modifier:float = 0.5 ## This needs to be with other Options in a singleton so it can be requested.

func _ready() -> void:
	GameEvents.turn_started.connect(_on_turn_started)
	GameEvents.turn_ended.connect(_on_turn_ended)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.weapon_updated.connect(_on_weapon_updated)
	
@warning_ignore("unused_parameter")
func check_cached_volume(audio_stream_player, override_volume_db:float = _sfx_volume_modifier) -> void:
	if not audio_stream_player in initial_db_values:
		initial_db_values[audio_stream_player] = audio_stream_player.get_volume_db()
		
func get_cached_volume(audio_stream_player) -> float:
	if audio_stream_player in initial_db_values:
		return initial_db_values[audio_stream_player]
	else:
		return _sfx_volume_modifier
	
func _on_turn_started(_player) -> void:
	if sfx_turn_started:
		sfx_turn_started.play()
	
func _on_turn_ended(_player) -> void:
	if sfx_turn_ended:
		sfx_turn_ended.play()

func _on_round_started() -> void:
	if sfx_round_started:
		sfx_round_started.play()
	if sfx_soundtrack:
		sfx_soundtrack.stream = soundtrack_file
		sfx_soundtrack.play()
	
func _on_round_ended() -> void:
	if sfx_round_ended:
		sfx_round_ended.play()
	if sfx_soundtrack:
		sfx_soundtrack.stop()
	
func _on_weapon_updated(_weapon) -> void:
	# Weapons have their own equip SFX that we could leverage,
	# but if you want one sound for all weapon changes just as an
	# alert, this is the way.
	if sfx_weapon_updated:
		sfx_weapon_updated.play()
