class_name HUDElement extends HBoxContainer

@onready var label: Label = $Label
@onready var value: Label = $Value

func set_value(input_value):
	value.text = str(input_value)
	
func set_label(input_value):
	label.text = str(input_value)
