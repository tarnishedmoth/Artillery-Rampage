class_name ButtonUpgradeSelection extends Button

signal selected(button:ButtonUpgradeSelection)

@export var mod_bundle:ModBundle

## If randomize chosen then a random mod is generated per the type specification
@export var randomize_mod:bool = false
@export var random_mod_types:Array[ModBundle.Types] = [ModBundle.Types.WEAPON]

@onready var small_question_marks: CPUParticles2D = %SmallQuestionMarks
@onready var big_question_marks: CPUParticles2D = %BigQuestionMarks
@onready var original_modulate:Color = modulate
var hover_modulate:Color = Color.GOLDENROD

var particles_tween

func _init() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func get_mod_bundle() -> ModBundle:
	if randomize_mod:
		return PlayerUpgradesClass.generate_random_upgrade(random_mod_types)
	return mod_bundle

func _on_pressed() -> void:
	selected.emit(self)
	disabled = true

func _on_mouse_entered() -> void:
	if particles_tween:
		if particles_tween.is_running():
			particles_tween.kill()
	particles_tween = create_tween()
	particles_tween.set_parallel(true)
	particles_tween.tween_property(small_question_marks, ^"modulate", hover_modulate, Juice.SNAP)
	particles_tween.tween_property(small_question_marks, ^"speed_scale", 2.0, Juice.SNAPPY)

func _on_mouse_exited() -> void:
	if particles_tween:
		if particles_tween.is_running():
			particles_tween.kill()
	particles_tween = create_tween()
	particles_tween.set_parallel(true)
	particles_tween.tween_property(small_question_marks, ^"modulate", original_modulate, Juice.SNAP)
	particles_tween.tween_property(small_question_marks, ^"speed_scale", 1.0, Juice.SNAPPY)
