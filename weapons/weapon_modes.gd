class_name WeaponModes extends Node

@export var modes: Array

@onready var parent: Weapon = get_parent()

var current_mode:int = 0

var display:LabelValue = LabelValue.new()

func _ready() -> void:
	parent.mode = 0
	parent.modes_total = modes.size()
	parent.mode_node = self
	parent.mode_change.connect(_on_weapon_mode_change)

func _exit_tree() -> void:
	if parent:
		parent.mode = 0
		parent.modes_total = 0
		parent.mode_node = null
	
func get_display_text() -> LabelValue:
	return display

func _on_weapon_mode_change(mode: int) -> void:
	current_mode = mode
	print_debug("Mode set to %s: value is %s" % [current_mode, modes[current_mode]])

class LabelValue:
	var label = "Label"
	var value = "Value"
