extends Node2D

@export var post_processing_scene: PackedScene
@onready var post_processing_effects: PostProcessingEffects = $PostProcessing

func _ready() -> void:
	if not post_processing_scene:
		return
	print_debug("%s - Adding post-processing scene=%s" % [name, post_processing_scene.resource_path])
	var effect_node: Node2D = post_processing_scene.instantiate() as Node2D
	if not effect_node:
		push_error("%s - Could not instantiate post-processing scene=%s" % [name, post_processing_scene.resource_path])
		return
	post_processing_effects.apply_effect(effect_node)
