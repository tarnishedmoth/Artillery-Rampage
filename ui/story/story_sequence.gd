class_name StorySequence extends Control

@onready var next_button: Button = %NextButton
@onready var skip_button:Button = %SkipButton

func _ready() -> void:
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_on_skip)


func _on_next() -> void:
	print_debug("on_next")
	await _go_to_next_scene()
	
func _on_skip() -> void:
	print_debug("on_skip")
	await _go_to_next_scene()

	
func _go_to_next_scene() -> void:
	await SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap, 0)
