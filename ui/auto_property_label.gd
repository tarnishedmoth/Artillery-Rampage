class_name PropertyLabel extends Label

@export var label:String
@export var parameter_path:String

@onready var parent = get_parent()

func _physics_process(delta: float) -> void:
	if parameter_path:
		if label:
			text = label + " "
		else:
			text = ""
		text += str(parent.get(parameter_path))
