extends Node

@export var ai_count_spread:Dictionary[Difficulty.DifficultyLevel, Vector2]
@export var disable_teams:Dictionary[Difficulty.DifficultyLevel, bool]

func _ready() -> void:
	GameEvents.level_loaded.connect(_on_level_loaded)

func _on_level_loaded(level:GameLevel) -> void:
	print_debug("%s: on_level_loaded: %s" % [name, level.level_name])
	_modify_artillery_spawner(level.spawner)
	
func _modify_artillery_spawner(spawner: ArtillerySpawner) -> void:
	var ai_count:Vector2i = spawner.default_ai_players
	var current_difficulty := Difficulty.current_difficulty
	
	var ai_count_spread:Vector2 = ai_count_spread.get(current_difficulty, Vector2(0.0, 1.0))
	var disable_teams:bool = disable_teams.get(current_difficulty, false)
	
	spawner.default_ai_players = Vector2i(lerp(ai_count.x, ai_count.y, ai_count_spread.x), lerp(ai_count.x, ai_count.y, ai_count_spread.y))
	if disable_teams:
		spawner.num_ai_teams = 0
		
	print_debug("%s: Modify Artillery Spawner for %s - ai_count_spread=%s; ai_players=%; disable_teams=%s" % [name, str(current_difficulty), str(ai_count_spread), str(spawner.default_ai_players), str(disable_teams)])
