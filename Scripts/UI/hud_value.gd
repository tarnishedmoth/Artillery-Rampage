class_name HUDElement extends HBoxContainer

@onready var value: Label = $Value

func set_value(input_value):
	value.text = str(input_value)
	
func _ready() -> void:
	pass # Replace with function body.
