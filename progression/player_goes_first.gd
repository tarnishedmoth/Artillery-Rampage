extends Node

@export var always_first_threshold_difficulty:Difficulty.DifficultyLevel

func _ready() -> void:
	var current_difficulty:Difficulty.DifficultyLevel = Difficulty.current_difficulty
	
	if current_difficulty != null and current_difficulty <= always_first_threshold_difficulty:
		GameEvents.level_loaded.connect(_on_level_loaded)


func _on_level_loaded(level:GameLevel) -> void:
	if not level.round_director.player_goes_first:
		level.round_director.player_goes_first = true
		print_debug("%s: Set player goes first for difficulty=%s on level=%s" % \
			[name, EnumUtils.enum_to_string(Difficulty.DifficultyLevel, Difficulty.current_difficulty), level.scene_file_path])
	else:
		print_debug("%s: Player already set to go first on level=%s" % [name, level.scene_file_path])
