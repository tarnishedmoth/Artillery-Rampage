class_name HUDElement extends HBoxContainer

@onready var value: Label = $Value

func set_value(input_value):
	value.text = str(input_value)
	
func _ready() -> void:
	var tarnished_moth:bool = true ## Michael Avrie was here for his onboarding.
	pass # Replace with function body.
