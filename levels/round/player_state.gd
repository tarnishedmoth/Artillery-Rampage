
## Keeps track of persistent state across rounds
## used in conjunction with setting pending_state on the controller
## prior to adding it to the tree
# TODO: Maybe extend from Resource so we can save/load using ResourceLoader/ResourceSaver as an easy
# way to save/load player state from file
# We would then wrap that in a SaveGameState that tracks other state like current level
# and things not specific to the player
# See https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html
class_name PlayerState

# Create explicit private variable so we can access in the "destructor" notification
var _weapons: Array[Weapon]

var weapons: Array[Weapon]:
	set(value):
		# Possible memory leak but we treat player state as immmutable
		if not _weapons.is_empty():
			push_warning("PlayerState: weapons already set - clearing - possible memory leak!")
		_weapons.clear()
		_weapons.resize(value.size())
		# Make sure copy doesn't retain parent reference
		for i in range(value.size()):
			_weapons[i] = value[i].duplicate()
			var w: Weapon = _weapons[i]
			# Remove any parent reference if it was also duplicated
			if w.get_parent():
				w.get_parent().remove_child(w)
			# TODO: Hack to force reconfigure on attach - maybe best to create the state in the weapon itself
			w.barrels.clear()
	get:
		# Explicit function to get a copy as don't want to make expensive copies by default
		return _weapons

var health: float
var max_health: float

func get_weapons_copy() -> Array[Weapon]:
	var copy: Array[Weapon] = []
	copy.resize(weapons.size())
	for i in range(copy.size()):
		copy[i] = weapons[i].duplicate()
	return copy

func _notification(what: int) -> void:
	# Cannot access property or self see - https://github.com/godotengine/godot/issues/80834
	if what == NOTIFICATION_PREDELETE:
		for w in _weapons:
			if is_instance_valid(w):
				w.queue_free()
		_weapons.clear()

# Don't add to Savable group as this is managed by PlayerStateManager
#region Savable

const SAVE_STATE_KEY = "player"

static func delete_save_state(save: SaveState) -> void:
	if save and save.state:
		save.state.erase(SAVE_STATE_KEY)
		
static func deserialize_from_save_state(save: SaveState) -> PlayerState:
	if not save or not save.state or not save.state.has(SAVE_STATE_KEY):
		print_debug("No save state found")
		return null
	
	var serialized_player_state: Dictionary = save.state[SAVE_STATE_KEY]
	var state:PlayerState = PlayerState.new()

	state.health = serialized_player_state.health
	state.max_health = serialized_player_state.max_health
	
	var weapons:Array[Weapon] = []
	for w in serialized_player_state.weapons:
		if w.has("res"):
			var weapon:Weapon = SaveState.safe_load_scene(w.res) as Weapon
			if weapon:
				weapon.current_ammo = w.ammo
				weapons.push_back(weapon)
			else:
				push_warning("PlayerState: weapon is not valid - skipping")
		else:
			push_warning("PlayerState: weapon does not have res - skipping")
	
	state.weapons = weapons
	
	return state

func serialize_save_state(game_state:SaveState) -> void:
	var serialized_player_state:Dictionary = {}
	serialized_player_state.health = health
	serialized_player_state.max_health = max_health

	var serialized_weapon_state: Array[Dictionary] = []
	
	for w in weapons:
		if is_instance_valid(w):
			var weapon_state: Dictionary = {}
			weapon_state.res = w.scene_file_path
			weapon_state.ammo = w.current_ammo
			serialized_weapon_state.push_back(weapon_state)
		else:
			push_warning("PlayerState: weapon is not valid - skipping")

	serialized_player_state.weapons = serialized_weapon_state
	game_state.state[SAVE_STATE_KEY] = serialized_player_state
#endregion
