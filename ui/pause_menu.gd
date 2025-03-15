extends Control

var paused = false;

func _ready():
	self.hide()

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
