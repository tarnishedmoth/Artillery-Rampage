class_name WindModifierConfig extends Resource

## Wall types that this wind modifier matches
# Array[Walls.WallType] doesn't work on resources. It becomes Array[int]
# So use export_enum Array[String] workaround
@export_enum("Warp", "Elastic", "Accelerate", "Sticky", "None") 
var wall_types:PackedStringArray:
	set(value):
		wall_types = value
		EnumUtils.enums_from_strings(Walls.WallType, wall_types, wall_type_values)

@export_enum("Easy", "Normal", "Hard") 
var difficulties:PackedStringArray:
	set(value):
		difficulties = value
		EnumUtils.enums_from_strings(Difficulty.DifficultyLevel, difficulties, difficulty_values)

@export_range(0, 1e9, 1, "or_greater")
var wind_max_abs:int = 100

var wall_type_values:Array[Walls.WallType] = []
var difficulty_values:Array[Difficulty.DifficultyLevel] = []

func matches(game_level:GameLevel, difficulty:Difficulty.DifficultyLevel) -> bool:
	return (not difficulty_values or difficulty in difficulty_values) and \
	 		(not wall_type_values or game_level.walls.wall_mode in wall_type_values)

func apply_to(wind:Wind) -> void:
	var wind_size:float = wind.wind_size
	if wind_size > wind_max_abs:
		var existing_wind:Vector2 = wind.wind
		wind.wind = wind_max_abs / wind_size * existing_wind
		print_debug("WindModifierConfig: Clamp wind from %s to %s" % [existing_wind, wind.wind])
