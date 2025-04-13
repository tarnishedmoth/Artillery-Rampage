class_name StorySequence extends Control

var current_slide:int = 0
var total_slides:int:
	get: return slides.size()

@onready var slides:Array = %StorySlides.get_children()
@onready var next_button: Button = %NextButton
@onready var skip_button:Button = %SkipButton

func _ready() -> void:
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_on_skip)
	
	for slide in slides:
		slide.hide()
	slides.front().show()
	
func next_slide() -> void:
	%Radio.play()
	%StorySlides.get_child(current_slide).hide()
	current_slide += 1
	%StorySlides.get_child(current_slide).show()

func _on_next() -> void:
	#print_debug("on_next")
	if current_slide + 1 < total_slides:
		next_slide()
	else:
		await _go_to_next_scene()
	
func _on_skip() -> void:
	print_debug("on_skip")
	await _go_to_next_scene()

	
func _go_to_next_scene() -> void:
	await SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap, 0)
