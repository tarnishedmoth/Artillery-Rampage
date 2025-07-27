extends Area3D

@onready var label: Label3D = $XRDebugLabel3D

var label_tween: Tween
@export var label_flash_color: Color = Color.RED

func load_ammo(ammo:PickableAmmo) -> void:
	print_debug("Loaded ammo %s." % [ammo.display_name])
	
	if label_tween:
		label_tween.kill()
	label_tween = create_tween()
	var orig_text: String = label.text
	label_tween.tween_callback(label.set_text.bind("Loaded %s." % [ammo.display_name]))
	label_tween.tween_property(label, ^"modulate", Color.WHITE, 1.0).from(label_flash_color)
	label_tween.tween_callback(label.set_text.bind(orig_text))
	ammo.despawn()

func _on_body_entered(body: Node3D) -> void:
	if body is PickableAmmo:
		load_ammo(body)
