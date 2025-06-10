extends Node

func _ready() -> void:
	# Skip if precompiler running
	if SceneManager.is_precompiler_running:
		return
	
	var story_level = SceneManager.current_story_level
	if story_level and story_level.force_player_goes_first:
		GameEvents.level_loaded.connect(_on_level_loaded)
		
func _on_level_loaded(level:GameLevel) -> void:
	if level.round_director.player_goes_first:
		print_debug("%s: Player already set to go first on level=%s" % [name, level.scene_file_path])
		return
	
	print_debug("%s: Set player to go first on level=%s" % [name, level.scene_file_path])
	level.round_director.player_goes_first = true
