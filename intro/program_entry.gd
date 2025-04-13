extends Control

var tween

func _ready() -> void:
	modulate = Color.BLACK
	%HomeTeamIcon.modulate = Color.TRANSPARENT
	%MadeInGodot.modulate = Color.TRANSPARENT
	%Precompilation.modulate = Color.TRANSPARENT
	
	await Juice.fade_in(self, Juice.SNAP, Color.BLACK).finished
	
	tween = create_tween().set_parallel()
	tween.tween_property(%HomeTeamIcon, "modulate", Color.WHITE, Juice.PATIENT).set_ease(Tween.EASE_OUT)
	tween.tween_property(%HomeTeamIcon, "position:y", 0.0, Juice.VERYLONG).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%MadeInGodot, "modulate", Color.WHITE, Juice.LONG).set_ease(Tween.EASE_IN)
	
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true) # Mute audio bus
	%Precompilation.completed.connect(_on_precompilation_completed)
	%Precompilation.run()

func _on_precompilation_completed() -> void:
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.4).set_trans(Tween.TRANS_QUAD)
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu, 0.0)
