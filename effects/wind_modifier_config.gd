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

## Changes the max wind variance if >= 0
@export
var wind_max_variance:int = -1

var wall_type_values:Array[Walls.WallType] = []
var difficulty_values:Array[Difficulty.DifficultyLevel] = []

func matches(game_level:GameLevel, difficulty:Difficulty.DifficultyLevel) -> bool:
	return (not difficulty_values or difficulty in difficulty_values) and \
	 		(not wall_type_values or game_level.walls.wall_mode in wall_type_values)

func apply_to(wind:Wind) -> void:
	var current_wind_max:int = wind.wind_max
	if current_wind_max > wind_max_abs:
		var wind_scale:float = float(wind_max_abs) / current_wind_max
		if wind.wind_min > 0:
			wind.wind_min = roundi(wind.wind_min * wind_scale)
		wind.wind_max = roundi(wind.wind_max * wind_scale)
		# Re-randomize with new scales
		wind.randomize_wind()
		print_debug("WindModifierConfig: Scale wind max from %d to %d" % [current_wind_max, wind.wind_max])
	if wind_max_variance >= 0:
		print_debug("WindModifierConfig: Change wind max variance from %d to %d" % [wind.max_per_orbit_variance, wind_max_variance])
		wind.max_per_orbit_variance = wind_max_variance
