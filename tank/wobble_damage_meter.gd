class_name WobbleDamagerMeter extends Node2D

## Connect the AimDamableWobble node
@export
var aim_damage_wobble: AimDamageWobble

@onready var bar: ColorRect = $ColorRect

func _ready() -> void:
	if SceneManager.is_precompiler_running:
		return
	if not aim_damage_wobble:
		push_error("%s - Missing configuration; aim_damage_wobble=%s" % [name, aim_damage_wobble])
		return
	aim_damage_wobble.wobble_updated.connect(_on_wobble_updated)
	
func _on_wobble_updated() -> void:
	# FIXME: Hack - positioning all busted and it always shows at origin
	bar.global_position = aim_damage_wobble._player.global_position + position
	
	# TODO: Placeholder color lerping
	var lerped_color: Color = Color.GREEN.lerp(Color.RED, fmod(aim_damage_wobble.deviation_alpha, 2.0))
	bar.color = lerped_color 
