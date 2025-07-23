extends SubViewport

func _exit_tree() -> void:
	if not SceneManager.is_quitting_game:
		push_error("Internal scene root is exiting tree!")
