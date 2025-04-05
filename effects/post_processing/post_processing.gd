## Manager for applying post processing effects to the scene
## Example a nuke explosion, night filter
class_name PostProcessingEffects extends CanvasLayer

@onready var back_buffer: BackBufferCopy = $ViewportBackBuffer

func apply_effect(effect: Node2D) -> void:
	back_buffer.add_child(effect)
