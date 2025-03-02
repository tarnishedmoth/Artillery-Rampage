extends Control

var paused = false;

func _ready():
	self.hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("pause"):
		pauseMenu()

func pauseMenu():
	paused = !paused
	
	if paused:
		self.show()
		get_tree().paused = paused
	else:
		self.hide()
		get_tree().paused = paused	
	

func _on_button_pressed():
	if paused:
		pauseMenu()
