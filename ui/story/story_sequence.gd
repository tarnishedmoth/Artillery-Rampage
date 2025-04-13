class_name StorySequence extends Control

var current_slide:int = 0
var total_slides:int:
	get: return %StorySlides.get_children().size()

@export var texts:Array[Control]
@onready var slides:Array = %StorySlides.get_children()
@onready var next_button: Button = %NextButton
@onready var skip_button:Button = %SkipButton

var auto_narrative = preload("res://narrative/auto_narrative.tscn")
var button_highlight_tween

func _ready() -> void:
	auto_narrative = auto_narrative.instantiate()
	add_child(auto_narrative)
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_on_skip)
	
	for slide in slides:
		#auto_narrative.replace_story_keywords(texts[current_slide])
		slide.hide()
	for control in texts:
		control.text = auto_narrative.replace_story_keywords(control.text)
	next_slide()
	
func next_slide() -> void:
	%Radio.play()
	if not current_slide == 0:
		%StorySlides.get_child(current_slide-1).hide()
	TypewriterEffect.apply_to(texts[current_slide])
	%StorySlides.get_child(current_slide).show()
	current_slide += 1
	
	if button_highlight_tween: button_highlight_tween.kill()
	button_highlight_tween = create_tween()
	button_highlight_tween.tween_property(%NextButton, "modulate", %NextButton.modulate, Juice.SMOOTH).from(Color.TRANSPARENT)
	button_highlight_tween.tween_property(%NextButton, "modulate", %NextButton.modulate, Juice.PATIENT).from(Color.TRANSPARENT)
	button_highlight_tween.tween_property(%NextButton, "modulate", %NextButton.modulate, Juice.PATIENT).from(Color.TRANSPARENT)
func _on_next() -> void:
	#print_debug("on_next")
	if current_slide < total_slides:
		next_slide()
	else:
		await _go_to_next_scene()
	
func _on_skip() -> void:
	print_debug("on_skip")
	await _go_to_next_scene()

	
func _go_to_next_scene() -> void:
	await SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryMap, 0)
