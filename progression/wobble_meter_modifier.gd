extends Node

var _existing_wobble: AimDamageWobble
var _wobble_activator:Node

## TODO: Export alternative curve resources to change speed and angle to modify the wobble behavior
# Resource would also indicate if enabled or not

func _ready() -> void:
	GameEvents.player_added.connect(_on_player_added)

func _on_player_added(player: TankController) -> void:
	if player is not Player:
		return
		
	var activators := get_tree().get_nodes_in_group(Groups.WobbleActivator).filter(
		func(activator) -> bool: return Groups.get_parent_in_group(activator, Groups.Player) != null)
	if activators.size() == 1:
		_wobble_activator = activators.front()
		_existing_wobble = _wobble_activator.get_parent() as AimDamageWobble
		print_debug("%s: Player has wobble activator %s -> %s" % [name, _wobble_activator, _existing_wobble])
		
		if _wobble_activator and _existing_wobble:
			_update_wobble(Difficulty.current_difficulty)
			GameEvents.difficulty_changed.connect(_on_difficulty_changed)		
	
func _update_wobble(difficulty: Difficulty.DifficultyLevel) -> void:
	if is_instance_valid(_wobble_activator):
		_wobble_activator.enabled = difficulty != Difficulty.DifficultyLevel.EASY

func _on_difficulty_changed(new_difficulty: Difficulty.DifficultyLevel, old_difficulty: Difficulty.DifficultyLevel) -> void:
	_update_wobble(new_difficulty)
