class_name WobbleDamagerMeter extends Node2D

## Connect the AimDamableWobble node
@export
var aim_damage_wobble: AimDamageWobble

@onready var bar: ColorRect = $ColorRect

var _color_material:ShaderMaterial

func _ready() -> void:
	if SceneManager.is_precompiler_running:
		return
	if not aim_damage_wobble:
		push_error("%s - Missing configuration; aim_damage_wobble=%s" % [name, aim_damage_wobble])
		return
		
	_color_material = bar.material as ShaderMaterial
	if not _color_material:
		push_error("%s - missing ShaderMaterial on ColorRect" % name)
		return
		
	aim_damage_wobble.wobble_updated.connect(_on_wobble_updated)
	
func _on_wobble_updated() -> void:
	# TODO: Placeholder color lerping
	var lerped_color: Color = Color.GREEN.lerp(Color.RED, fmod(aim_damage_wobble.deviation_alpha, 2.0))
	# Need to use a material; otherwise, the modulate effects and other shading bleeds through
	# into the color rect but using a pixel shader with explicit set color overrides anything else
	_color_material.set_shader_parameter(&"Color", lerped_color)
