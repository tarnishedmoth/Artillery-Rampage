extends Control

var paused = false;

@onready var options_menu: PanelContainer = %OptionsMenu
@onready var pause_menu: Control = %PauseMenu

@onready var exit_to_desktop_button: Button = %QuitToDesktop


func _ready():
	if OS.get_name() == "Web":
		exit_to_desktop_button.hide()
		
	if not SceneManager.play_mode == SceneManager.PlayMode.PLAY_NOW:
		%PauseMenu.get_node("NewGame").hide()
	hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_visibility()

func toggle_visibility():
	paused = !paused
	
	if paused:
		self.show()
		get_tree().paused = paused
	else:
		self.hide()
		get_tree().paused = paused	
	

func _on_resume_pressed():
	toggle_visibility()

func _on_main_menu_pressed() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu)

func _on_quit_to_desktop_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	pause_menu.hide()
	options_menu.show()

func _on_options_menu_closed() -> void:
	pause_menu.show()
	options_menu.hide()


func _on_new_game_pressed() -> void:
	# Start a new quick match
	
	#PlayerStateManager.enable = false
	#SceneManager.play_mode = SceneManager.PlayMode.PLAY_NOW
	
	var level: StoryLevel = SceneManager.levels_always_selectable.levels.pick_random()
	if level:
		SceneManager.switch_scene_file(level.scene_res_path)
