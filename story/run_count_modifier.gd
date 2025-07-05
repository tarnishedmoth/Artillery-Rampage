extends Node

var _artillery_spawner: ArtillerySpawner
var _story_level: StoryLevel = SceneManager.current_story_level

class WeaponWeights:
	var weapon: PackedScene
	var weight: float

class AIRunLevelWeaponConfig:
	var additional_weapons: Array[WeaponWeights] 
	var additional_weapon_count: int

func _ready() -> void:
	# Skip if precompiler running
	if SceneManager.is_precompiler_running:
		return

	_story_level = SceneManager.current_story_level
	if _story_level:
		GameEvents.level_loaded.connect(_on_level_loaded)
	else:
		push_error("%s: current story level NULL when in story mode!" % [name])

func _on_level_loaded(level: GameLevel) -> void:
	print_debug("%s: on_level_loaded: %s" % [name, level.level_name])

	_artillery_spawner = level.spawner
	
	# HACK: To workaround the story level state being restored after the level is loaded
	# so need to wait an additional frame
	await get_tree().process_frame
	
	_modify_artillery_spawner(_artillery_spawner)

	# Need to modify the counts given the new difficulty	
	GameEvents.difficulty_changed.connect(_on_difficulty_changed)
	
func _modify_artillery_spawner(spawner: ArtillerySpawner) -> void:
	var story_level_state:StoryLevelState = SceneManager.story_level_state
	if not story_level_state:
		push_error("%s: StoryLevelState not found in tree - unable to check run number" % name)
		return
	
	var run_count:int = story_level_state.run_count
	if run_count <= 0:
		push_error("%s: Invalid run count %d" % [name, run_count])
		return
	
	spawner.default_ai_players += Vector2i.ONE * (run_count - 1)

	# Clamp to max
	var max_ai_players:int = _story_level.absolute_max_ai

	spawner.default_ai_players = Vector2i(
		mini(spawner.default_ai_players.x, max_ai_players),
		mini(spawner.default_ai_players.y, max_ai_players)
	)

	var modifier_weapon_config: AIRunLevelWeaponConfig = _get_run_level_weapon_config(run_count)
	if modifier_weapon_config:
		_modify_ai_weapons_by_config(spawner, modifier_weapon_config)

func _get_run_level_weapon_config(run_count: int) -> AIRunLevelWeaponConfig:
	var run_modifiers:AIRunModifiers = SceneManager.story_levels.run_modifiers
	if not run_modifiers:
		return null

	var weapon_config:AIRunLevelWeaponConfig = AIRunLevelWeaponConfig.new()
	weapon_config.additional_weapons = []
	weapon_config.additional_weapon_count = run_modifiers.additional_weapon_count_by_run_count.get(run_count, 0)

	for config in run_modifiers.weapon_config:
		var match_diff:int = run_count - config.min_run_count
		if match_diff < 0:
			continue

		var weapon_weights := WeaponWeights.new()
		weapon_weights.weapon = config.weapon
		if config.weight_by_run.has(match_diff):
			weapon_weights.weight = config.weight_by_run.get(match_diff)
		elif match_diff > 0 and not config.weight_by_run.is_empty():
			# Use largest
			weapon_weights.weight = config.weight_by_run[config.weight_by_run.keys().max()]
		else:
			weapon_weights.weight = 1.0
		
		weapon_config.additional_weapons.push_back(weapon_weights)
	return weapon_config

func _modify_ai_weapons_by_config(spawner: ArtillerySpawner, modifier_weapon_config: AIRunLevelWeaponConfig) -> void:
	# Sort so that highest priority weapons come first
	modifier_weapon_config.additional_weapons.sort_custom(func(a,b): return a.weight > b.weight)

	spawner.artillery_ai_starting_weapon_count += Vector2i.ONE * modifier_weapon_config.additional_weapon_count
	var min_weapon_count:int = spawner.artillery_ai_starting_weapon_count.x

	var final_weapons:Array[PackedScene] = []
	for weapon_config in modifier_weapon_config.additional_weapons:
		if weapon_config.weight >= 1.0:
			final_weapons.push_back(weapon_config.weapon)
	
	# Now add regular weapons
	if final_weapons.size() < min_weapon_count:
		for weapon in spawner.artillery_ai_starting_weapons:
			if not final_weapons.any(func(elm): return elm.resource_path == weapon.resource_path):
				final_weapons.push_back(weapon)

	# Add in low priority weapons
	if final_weapons.size() < min_weapon_count:
		for weapon_config in modifier_weapon_config.additional_weapons:
			var weapon:PackedScene = weapon_config.weapon
			if weapon_config.weight < 1.0 and not final_weapons.any(func(elm): return elm.resource_path == weapon.resource_path):
				final_weapons.push_back(weapon)

	spawner.artillery_ai_starting_weapons = final_weapons
	
	# Add lowest priority weapons next
func _on_difficulty_changed(_new_difficulty: Difficulty.DifficultyLevel, _old_difficulty: Difficulty.DifficultyLevel) -> void:
	# Wait a frame to make sure that the default processing runs first
	await get_tree().process_frame
	if is_instance_valid(_artillery_spawner):
		_modify_artillery_spawner(_artillery_spawner)
