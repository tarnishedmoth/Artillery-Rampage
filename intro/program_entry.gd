extends Control

func _ready() -> void:
	modulate = Color.BLACK
	%HomeTeamIcon.modulate = Color.TRANSPARENT
	%MadeInGodot.modulate = Color.TRANSPARENT
	#%Precompilation.modulate = Color.TRANSPARENT
	%ProgressUI.modulate = Color.TRANSPARENT
	
	
	await Juice.fade_in(self, Juice.SNAPPY, Color.BLACK).finished
	%ProgressUI.start()
	
	var tween = create_tween()
	tween.tween_property(%HomeTeamIcon, "modulate", Color.WHITE, Juice.PATIENT).set_ease(Tween.EASE_OUT)
	tween.tween_property(%HomeTeamIcon, "position:y", %HomeTeamIcon.position.y - 256.0, Juice.VERYLONG).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel()
	tween.tween_property(%MadeInGodot, "modulate", Color.WHITE, Juice.LONG).set_ease(Tween.EASE_IN)
	
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true) # Mute audio bus
	%Precompilation.completed.connect(_on_precompilation_completed)
	
	await get_tree().create_timer(Juice.SMOOTH).timeout
	%Precompilation.run()

func _on_precompilation_completed() -> void:
	var tween = create_tween()
	tween.tween_interval(Juice.SMOOTH)
	tween.tween_property(self, "modulate", Color.BLACK, Juice.FAST).set_trans(Tween.TRANS_QUAD)
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu, 0.0)
