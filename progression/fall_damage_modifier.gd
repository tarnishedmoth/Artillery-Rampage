extends Node

var _player_tank:Tank

@export var disable_fall_damage:Dictionary[Difficulty.DifficultyLevel, bool]

func _ready() -> void:
	GameEvents.player_added.connect(_on_player_added)

func _on_player_added(player: TankController) -> void:
	if player is not Player:
		return
	_player_tank = player.tank
	if not _player_tank.enable_fall_damage:
		print_debug("%s: Nothing to do as fall damage already disabled on the player tank" % [name])
		return
	
	_update_fall_Damage(Difficulty.current_difficulty)
	GameEvents.difficulty_changed.connect(_on_difficulty_changed)
	
func _update_fall_Damage(difficulty: Difficulty.DifficultyLevel) -> void:
	if not is_instance_valid(_player_tank):
		return
	var enable_fall_damage:bool = not disable_fall_damage.get(difficulty, false)
	print_debug("%s - Update Fall damage for Player to %s" % [name, str(enable_fall_damage)])
	_player_tank.enable_fall_damage = enable_fall_damage

func _on_difficulty_changed(new_difficulty: Difficulty.DifficultyLevel, old_difficulty: Difficulty.DifficultyLevel) -> void:
	_update_fall_Damage(new_difficulty)
