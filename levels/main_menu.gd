extends Node2D

#region--Variables
@export var revealables:Array[Control] ## Will reveal their text as determined by reveal_speed
@export var reveal_speed: float = 0.15

@export var credits_line_scroll_frequency:float = 1.5 ## In seconds, advances credits one line.
var _current_credits_list_line:int = 0

@onready var credits_list: RichTextLabel = %CreditsList
@onready var credits_list_line_count = credits_list.get_line_count()
var credits_list_is_focused:bool = false

@onready var main_menu: VBoxContainer = %MainMenu
@onready var options_menu: Control = %Options
@onready var level_select_menu: LevelSelect = %LevelSelect
@onready var exit_to_desktop_button: Button = %Quit

@onready var soundtrack: AudioStreamPlayer2D = %Soundtrack
#endregion


#region--Virtuals
func _ready() -> void:
	# Editor convenience
	main_menu.show()
	level_select_menu.hide()
	
	# Remove buttons that don't function on Web
	if OS.get_name() == "Web":
		exit_to_desktop_button.hide()
	
	start_typewriter_effect() # Typewriter effect
	per_line_scroll_credits() # Autoscrolling
	soundtrack.play()
#endregion

#region--Public Methods
# Scrolls the credits automatically as it isn't focused (mouse hover).
func per_line_scroll_credits() -> void:
	var scroller = Timer.new()
	scroller.timeout.connect(_on_scroller_timeout)
	add_child(scroller)
	scroller.start(credits_line_scroll_frequency)
	
func start_typewriter_effect() -> void:
	for node in revealables:
		TypewriterEffect.effect(node)
#endregion
#region--Private Methods
func _on_start_pressed() -> void:
	print_debug("Start button")
	PlayerStateManager.enable = true
	SceneManager.play_mode = SceneManager.PlayMode.STORY

	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryStart)

func _on_level_select_pressed() -> void:
	print_debug("Level select button")
	PlayerStateManager.enable = false
	SceneManager.play_mode = SceneManager.PlayMode.LEVEL_SELECT

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

func _on_scroller_timeout() -> void:
	if credits_list_is_focused: return
	_current_credits_list_line += 1
	if _current_credits_list_line > credits_list_line_count:
		_current_credits_list_line = 0
	credits_list.scroll_to_line(_current_credits_list_line)

func _on_credits_list_mouse_entered() -> void:
	credits_list_is_focused = true

func _on_credits_list_mouse_exited() -> void:
	credits_list_is_focused = false

func _on_play_now_pressed() -> void:
	PlayerStateManager.enable = false
	SceneManager.play_mode = SceneManager.PlayMode.PLAY_NOW
	
	var level: StoryLevel = level_select_menu.levels_always_selectable.levels.pick_random()
	if level:
		SceneManager.switch_scene_file(level.scene_res_path)
