extends Node2D

#region-- signals
#endregion


#region--Variables
# statics
# Enums
# constants
# @exports
@export var reveal_speed: float = 0.15
@export var credits_line_scroll_frequency:float = 1.5 ## In seconds, advances credits one line.

@export var revealables:Array[Control] ## Will reveal their text as determined by reveal_speed
# public
var revealer_timer:Timer
# _private
var _text_controls:Array
var _current_credits_list_line:int = 0
# @onready
@onready var credits_list: RichTextLabel = %CreditsList
@onready var credits_list_line_count = credits_list.get_line_count()
var credits_list_is_focused:bool = false

@onready var main_menu: VBoxContainer = %MainMenu
@onready var options_menu: Control = %Options
@onready var level_select_menu: Control = %LevelSelect

@onready var soundtrack: AudioStreamPlayer2D = %Soundtrack

#endregion


#region--Virtuals
#func _init() -> void: pass
#func _enter_tree() -> void: pass
func _ready() -> void:
	per_character_full_reveal()
	per_line_scroll_credits()
	soundtrack.play()
#func _input(event: InputEvent) -> void: pass
#func _unhandled_input(event: InputEvent) -> void: pass
#func _physics_process(delta: float) -> void: pass
#func _process(delta: float) -> void: pass
#endregion
#region--Public Methods
func per_line_scroll_credits() -> void:
	var scroller = Timer.new()
	scroller.timeout.connect(_on_scroller_timeout)
	add_child(scroller)
	scroller.start(credits_line_scroll_frequency)
	
func per_character_full_reveal() -> void:
	#_text_controls = find_text_controls()
	_text_controls = revealables
	clear_all_text(_text_controls)
	
	revealer_timer = Timer.new()
	revealer_timer.one_shot = true
	revealer_timer.timeout.connect(_on_reveal_timeout)
	add_child(revealer_timer)
	revealer_timer.start(reveal_speed)
	
func clear_all_text(text_nodes:Array) -> void:
	for node in text_nodes:
		node.set_visible_characters(0)

#func find_text_controls() -> Array[Control]:
	#var controls:Array[Control]
	#var children_and_children_of_children_etc = _recursive_find_children(self)
	#
	#for node in children_and_children_of_children_etc:
		#if node.has_method("set_visible_characters"):
			#controls.append(node)
	#
	#print_debug("Found ", children_and_children_of_children_etc.size()," text controls in main menu.")
	#return controls
#endregion
#region--Private Methods
func _on_start_pressed() -> void:
	print_debug("Start button")
	PlayerStateManager.enable = true
	SceneManager.next_level()

func _on_level_select_pressed() -> void:
	print_debug("Level select button")
	PlayerStateManager.enable = false
	level_select_menu.show()
	main_menu.hide()

func _on_options_pressed() -> void:
	print_debug("Options button")
	options_menu.show()
	main_menu.hide()

func _on_quit_pressed() -> void:
	get_tree().quit()
	
func _on_options_menu_closed() -> void:
	print_debug("Options menu closed -- main menu")
	options_menu.hide()
	main_menu.show()
	
#func _recursive_find_children(node:Node) -> Array:
	#var children:Array = node.get_children()
	#
	#if not children.is_empty():
		#for child in children:
			#var child_children = _recursive_find_children(child)
			#children.append_array(child_children)
	#return children

func _on_scroller_timeout() -> void:
	if credits_list_is_focused: return
	_current_credits_list_line += 1
	if _current_credits_list_line > credits_list_line_count:
		_current_credits_list_line = 0
	credits_list.scroll_to_line(_current_credits_list_line)

func _on_reveal_timeout() -> void:
	for node in _text_controls:
		node.set_visible_characters(node.visible_characters + 1)
		if node.visible_ratio >= 1.00:
			_text_controls.erase(node)
			print_debug("Typewriter reveal: an item fully revealed; items remaining to reveal: ",_text_controls.size()," controls.")
			break # Godot documentation says not to erase while iterating
	revealer_timer.start(clampf(revealer_timer.wait_time * 0.95, 0.012, 2.0)) # Accelerate


func _on_credits_list_mouse_entered() -> void:
	credits_list_is_focused = true

func _on_credits_list_mouse_exited() -> void:
	credits_list_is_focused = false
