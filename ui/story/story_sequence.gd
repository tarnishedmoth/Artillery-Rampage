class_name StorySequence extends Control

@onready var next_button: Button = %NextButton
@onready var skip_button:Button = %SkipButton

func _ready() -> void:
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_on_skip)


func _on_next() -> void:
	print("on_next")
	await SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu, 0)
	
func _on_skip() -> void:
	print("on_skip")
	await SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu, 0)
