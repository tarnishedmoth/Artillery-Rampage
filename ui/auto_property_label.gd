class_name PropertyLabel extends Label

@export var remote_object:Node

@export var label:String
@export var parameter_path:String = ""

@onready var parent = get_parent() if not remote_object else remote_object

func _physics_process(delta: float) -> void:
	if label:
		text = label + " "
	else:
		text = ""
	text += str(parent.get(parameter_path))
