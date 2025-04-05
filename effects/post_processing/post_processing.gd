## Manager for applying post processing effects to the scene
## Example a nuke explosion, night filter
class_name PostProcessingEffects extends CanvasLayer

@onready var back_buffer: BackBufferCopy = $ViewportBackBuffer
@export var game_timer_override: GameTimer

func apply_effect(effect: Node2D) -> void:
	if "get_game_time_seconds" in effect:
		effect.get_game_time_seconds = get_game_time
		
	back_buffer.add_child(effect)

func get_game_time() -> float:
	if game_timer_override:
		return game_timer_override.time_seconds
	elif SceneManager._current_level_root_node:
		return SceneManager.get_current_level_root().game_timer.time_seconds
	else:
		push_warning("%s - No Game Timer found! Defaulting to 0" % [name])
		return 0.0 
