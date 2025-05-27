extends Node

var _existing_wobble: AimDamageWobble
var _wobble_activator:Node

@export
var WobbleModifier:Dictionary[Difficulty.DifficultyLevel, WobbleDifficultyModifierResource]

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
	if not is_instance_valid(_wobble_activator) or not is_instance_valid(_existing_wobble):
		return

	var modifier_resource: WobbleDifficultyModifierResource = WobbleModifier.get(difficulty, null)
	if not modifier_resource:
		push_warning("%s: No wobble modifier resource for difficulty %s" % [name, difficulty])
		return

	_wobble_activator.enabled = modifier_resource.enabled
	if modifier_resource.enabled and modifier_resource.aim_deviation_period_v_damage and modifier_resource.aim_deviation_v_damage:
		_existing_wobble.aim_deviation_v_damage = modifier_resource.aim_deviation_v_damage
		_existing_wobble.aim_deviation_period_v_damage = modifier_resource.aim_deviation_period_v_damage
		_existing_wobble.recalculate_wobble()

func _on_difficulty_changed(new_difficulty: Difficulty.DifficultyLevel, _old_difficulty: Difficulty.DifficultyLevel) -> void:
	_update_wobble(new_difficulty)
