extends Label

func _ready() -> void:
	var version:String = _get_project_version()
	if version:
		text = "Version: %s" % version
	else:
		hide()
	
func _get_project_version() -> String:
	var version = ProjectSettings.get_setting("application/config/version")
	print_debug("Project version:", version)
	return version
