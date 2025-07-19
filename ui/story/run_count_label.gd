extends Label

@export var pretext:String = "Run #"
var run_count:int = 0

func _ready() -> void:
	hide()
	if SceneManager:
		if SceneManager.story_level_state:
			run_count = SceneManager.story_level_state.run_count
			if run_count > 1:
				show()
			else:
				hide()
			
			text = pretext + str(run_count)
			return
