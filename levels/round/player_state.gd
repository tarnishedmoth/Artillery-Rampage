
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
