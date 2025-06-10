extends Node

# TODO: Can fold these into AIDifficultyConfig resource
@export var ai_count_spread_diff:Dictionary[Difficulty.DifficultyLevel, Vector2]
@export var disable_teams_diff:Dictionary[Difficulty.DifficultyLevel, bool]
@export var ai_difficulty_map:Dictionary[Difficulty.DifficultyLevel, AIDifficultyConfig]

var _artillery_spawner:ArtillerySpawner
var _default_ai_players:Vector2i
var _default_num_ai_teams:int

func _ready() -> void:
	GameEvents.level_loaded.connect(_on_level_loaded)

func _on_level_loaded(level:GameLevel) -> void:
	print_debug("%s: on_level_loaded: %s" % [name, level.level_name])
	
	_artillery_spawner = level.spawner
	_default_ai_players = _artillery_spawner.default_ai_players
	_default_num_ai_teams = _artillery_spawner.num_ai_teams
	
	_modify_artillery_spawner(_artillery_spawner)
	
	## Listening in case this is a test level or a level that continues to spawn enemies later
	GameEvents.difficulty_changed.connect(_on_difficulty_changed)
	
func _modify_artillery_spawner(spawner: ArtillerySpawner) -> void:
	var ai_count:Vector2i = _default_ai_players
	var current_difficulty: Difficulty.DifficultyLevel = Difficulty.current_difficulty
	
	var ai_count_spread:Vector2 = ai_count_spread_diff.get(current_difficulty, Vector2(0.0, 1.0))
	var disable_teams:bool = disable_teams_diff.get(current_difficulty, false)

	var ai_difficulty_config:AIDifficultyConfig = ai_difficulty_map.get(current_difficulty)
	
	spawner.default_ai_players = Vector2i(
		floori(lerpf(ai_count.x, ai_count.y, ai_count_spread.x)),
		ceili(lerpf(ai_count.x, ai_count.y, ai_count_spread.y))
	)
	
	if ai_difficulty_config and ai_difficulty_config.ai_type_mappings:
		var mappings:Dictionary[PackedScene, PackedScene] = ai_difficulty_config.ai_type_mappings

		for i in spawner.artillery_ai_types.size():
			var artillery_type:PackedScene = spawner.artillery_ai_types[i]

			var remapped_type:PackedScene = mappings.get(artillery_type)
			if remapped_type:
				spawner.artillery_ai_types[i] = remapped_type
				print_debug("%s: Modify Artillery Spawner - remap AI %s -> %s" % [name, artillery_type.resource_path, remapped_type.resource_path])
				
	if disable_teams:
		spawner.num_ai_teams = 0
	else:
		spawner.num_ai_teams = _default_num_ai_teams
		
	print_debug("%s: Modify Artillery Spawner for %s - ai_count_spread=%s; ai_players=%s; disable_teams=%s" % [name, EnumUtils.enum_to_string(Difficulty.DifficultyLevel, current_difficulty), str(ai_count_spread), str(spawner.default_ai_players), str(disable_teams)])

func _on_difficulty_changed(_new_difficulty: Difficulty.DifficultyLevel, _old_difficulty: Difficulty.DifficultyLevel) -> void:
	if is_instance_valid(_artillery_spawner):
		_modify_artillery_spawner(_artillery_spawner)
