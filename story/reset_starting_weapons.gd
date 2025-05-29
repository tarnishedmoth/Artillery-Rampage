## Resets the player's starting weapons at the beginning of story mode
## as upgrades and weapons are earned through story progression and purchases through scrap and personnel
extends Node

# Assumes that we are in story mode, though technically could use it for any game mode if want to reset the state
func _ready() -> void:
	# Skip if precompiler running
	if SceneManager.is_precompiler_running:
		return
	GameEvents.level_loaded.connect(_on_level_loaded)

func _on_level_loaded(level:GameLevel) -> void:
	# Assumes that we only save when completing a level
	# If this is not the first level, then there is nothing to do 
	if SceneManager._current_level_index > 0:
		print_debug("%s: Skip resetting weapons as level=%s is level %d" % [name, level.level_name, SceneManager._current_level_index])
		return
	
	print_debug("%s: Will reset weapons as level=%s is the first level" % [name, level.level_name])
	GameEvents.player_added.connect(_on_player_added)

func _on_player_added(player:TankController) -> void:
	if not player is Player:
		return
	print_debug("%s: Reset weapons for player on first level" % [name])

	# Assumes first weapon is the default one that player should start with
	var existing_weapons:Array[Weapon] = player.get_weapons()
	if not existing_weapons:
		push_warning("%s: Player=%s has no weapons!" % [name, player])
		return
	
	# Make copy of default starting weapon since we are about to destroy all the weapons
	var default_starting_weapon: Weapon = existing_weapons.front().duplicate()
	print_debug("%s: Starting with weapon=%s" % [name, default_starting_weapon.display_name])

	player.remove_all_weapons(true)
	player.attach_weapons([default_starting_weapon])
