extends Node2D

#region-- signals
#endregion


#region--Variables
# statics
# Enums
# constants
# @exports
@export var credits_line_scroll_frequency:float = 0.9 ## In seconds, advances credits one line.
# public
# _private
var _current_credits_list_line:int = 0
# @onready
@onready var credits_list: RichTextLabel = %CreditsList
@onready var credits_list_line_count = credits_list.get_line_count()
#endregion


#region--Virtuals
#func _init() -> void: pass
#func _enter_tree() -> void: pass
func _ready() -> void:
	per_line_scroll_credits()
#func _input(event: InputEvent) -> void: pass
#func _unhandled_input(event: InputEvent) -> void: pass
#func _physics_process(delta: float) -> void: pass
#func _process(delta: float) -> void: pass
#endregion
#region--Public Methods
func scroll_credits(delta: float) -> void:
	pass
	
func per_line_scroll_credits() -> void:
	var scroller = Timer.new()
	scroller.timeout.connect(_on_scroller_timeout)
	add_child(scroller)
	scroller.start(credits_line_scroll_frequency)

#endregion
#region--Private Methods
func _on_start_pressed() -> void:
	pass # Replace with function body.

func _on_level_select_pressed() -> void:
	pass # Replace with function body.

func _on_options_pressed() -> void:
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_scroller_timeout() -> void:
	_current_credits_list_line += 1
	if _current_credits_list_line > credits_list_line_count:
		_current_credits_list_line = 0
	credits_list.scroll_to_line(_current_credits_list_line)
