extends Control

@onready var gd_text: Sprite2D = %GDText
@onready var gd_rocket: Sprite2D = %GDRocket
@onready var v_box_container: VBoxContainer = $VBoxContainer


func _ready() -> void:
	modulate = Color.BLACK
	v_box_container.modulate = Color.TRANSPARENT
	#%MadeInGodot.modulate = Color.TRANSPARENT
	#%Precompilation.modulate = Color.TRANSPARENT
	%ProgressUI.modulate = Color.TRANSPARENT
	
	
	await Juice.fade_in(self, Juice.SNAPPY, Color.BLACK).finished
	%ProgressUI.start()
	
	var tween = create_tween()
	tween.tween_property(v_box_container, "modulate", Color.WHITE, Juice.PATIENT).set_ease(Tween.EASE_OUT)
	tween.tween_property(gd_rocket, "position:y", gd_rocket.position.y - 256.0, Juice.VERYLONG).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
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
	tween.tween_callback(
		SceneManager.switch_scene_keyed.bind(SceneManager.SceneKeys.MainMenu, 0.0)
		)
