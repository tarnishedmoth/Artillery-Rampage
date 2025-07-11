class_name HUDElement extends HBoxContainer

@onready var label: Label = $Label
@onready var value: Label = $Value

var label_changed:bool = false ## Will be true if the value has visibly changed this frame. Will be false if the value is unchanged.
var value_changed:bool = false ## Will be true if the value has visibly changed this frame. Will be false if the value is unchanged.

func set_value(input_value):
	var input_string:String = str(input_value)
	
	if value.text != input_string:
		value.text = input_string
		
		value_changed = true
		await get_tree().process_frame
		value_changed = false
	
func set_label(input_value):
	var input_string:String = str(input_value)
	
	if label.text != input_string:
		label.text = input_string
		
		label_changed = true
		await get_tree().process_frame
		label_changed = false
