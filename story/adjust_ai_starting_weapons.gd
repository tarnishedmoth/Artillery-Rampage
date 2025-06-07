## Resets the AI's starting weapons at the start of a level in story mode to be in that level's allowed set if it is defined
extends Node

var _ai_config: AIStoryConfig

func _ready() -> void:
	# Skip if precompiler running
	if SceneManager.is_precompiler_running:
		return

	var story_level: StoryLevel = SceneManager.current_story_level
	if story_level:
		# Get the ai starting weapons for current difficulty
		_ai_config = _get_ai_config_by_difficulty(story_level, Difficulty.current_difficulty)
		if _ai_config:
			GameEvents.level_loaded.connect(_on_level_loaded)
		else:
			print_debug("%s: StoryLevel %s does not have ai starting weapons specified for difficulty=%s" % \
				[name, story_level.name, EnumUtils.enum_to_string(Difficulty.DifficultyLevel, Difficulty.current_difficulty)])
	else:
		push_error("%s: current story level NULL when in story mode!" % [name])

func _get_ai_config_by_difficulty(story_level: StoryLevel, difficulty: Difficulty.DifficultyLevel) -> AIStoryConfig:
	if difficulty == null:
		push_error("%s: Difficulty is currently NULL" % [name])
		return null
	
	var difficulty_ordinal:int = EnumUtils.enum_ordinal(Difficulty.DifficultyLevel, difficulty)

	# If we have a matching difficulty return it; otherwise, get nearest match on lower difficulty
	for i in range(difficulty_ordinal, -1, -1):
		var ai_config: AIStoryConfig = story_level.ai_config_by_difficulty.get(i)
		if ai_config:
			return ai_config
	
	return null

func _on_level_loaded(level:GameLevel) -> void:
	print_debug("%s: on_level_loaded: %s" % [name, level.level_name])

	_modify_artillery_spawner(level.spawner)

func _modify_artillery_spawner(spawner: ArtillerySpawner) -> void:
	print_debug("%s: Modify Artillery Spawner - difficulty=%s; ai_types=%s; ai_weapons=%s; ai_weapon_count=%s" % \
		[name, EnumUtils.enum_to_string(Difficulty.DifficultyLevel, Difficulty.current_difficulty), _debug_map_scene_array(_ai_config.artillery_ai_types), _debug_map_scene_array(_ai_config.weapons), str(_ai_config.weapon_count)])
	
	spawner.artillery_ai_starting_weapons = _ai_config.weapons
	spawner.artillery_ai_starting_weapon_count = _ai_config.weapon_count
	
	if _ai_config.artillery_ai_types:
		spawner.artillery_ai_types = _ai_config.artillery_ai_types

	# Spawn counts handled by the general difficulty modifier

func _debug_map_scene_array(scene_array) -> Array:
	return scene_array.map(func(w): return w.resource_path)
