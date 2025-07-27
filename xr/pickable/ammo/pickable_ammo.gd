class_name PickableAmmo extends XRToolsPickable

@export_placeholder("Lead Ball") var display_name: String:
	get: return display_name if display_name else "NO_DISPLAY_NAME"
	
@export var mesh:GeometryInstance3D

func _ready() -> void:
	if GlobalXR.debug_mode > 0:
		var label:XRDebugLabel3D = XRDebugLabel3D.new()
		label.text = display_name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.ignore_occlusion_culling = true
		add_child(label)

func despawn() -> void:
	if mesh:
		var fade_out:Tween = create_tween()
		fade_out.tween_property(mesh, ^"transparency", 1.0, 1.0)
		fade_out.tween_callback(queue_free)
	else:
		queue_free()
