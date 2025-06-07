extends Node

@export var wind_configs: Array[WindModifierConfig]

func _ready() -> void:
	if wind_configs:
		GameEvents.level_loaded.connect(_on_level_loaded)

func _on_level_loaded(level:GameLevel) -> void:
	print_debug("%s: on_level_loaded: %s" % [name, level.level_name])
	
	var difficulty: Difficulty.DifficultyLevel = Difficulty.current_difficulty

	var config := _get_matching_wind_modifier_config(level, difficulty)
	if config:
		print_debug("%s: Applying matching config for difficulty=%s" % [name, EnumUtils.enum_to_string(Difficulty.DifficultyLevel, difficulty)])
		config.apply_to(level.wind)


func _get_matching_wind_modifier_config(level:GameLevel, difficulty: Difficulty.DifficultyLevel) -> WindModifierConfig:
	# Return last matching config to allow overriding
	var matching_config:WindModifierConfig = null
	
	for config in wind_configs:
		if config.matches(level, difficulty):
			matching_config = config
	
	return matching_config
