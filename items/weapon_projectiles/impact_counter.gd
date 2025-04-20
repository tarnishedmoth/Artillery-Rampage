extends Node

@export var count_to_arm:int = 2 ## Projectile will be armed (will explode on next impact) after this many impacts counted.
@export var impact_delay_buffer:float = 0.25 ## The buffer prevents multiple impacts registering more quickly than this time in seconds.

@export_group("SFX", "sfx_")
@export var sfx_impact:AudioStreamPlayer2D ## Plays when impact detected
@export var sfx_armed:AudioStreamPlayer2D ## Plays once armed

@onready var parent:WeaponProjectile = get_parent()

var count:int = 0
var _buffer:float = 0.0
var _armed:bool = false

func disarm(): parent.should_explode_on_impact = false
func arm():
	_armed = true
	if sfx_armed: sfx_armed.play()
	
	await get_tree().create_timer(impact_delay_buffer).timeout
	
	if parent.calculated_hit: parent.calculated_hit = false # Hack for whatever is going on in there
	parent.should_explode_on_impact = true

func _ready() -> void:
	disarm()
	
func _physics_process(delta: float) -> void:
	if _buffer > 0.0:
		_buffer = maxf(0.0, _buffer-delta)

func _on_weapon_projectile_body_entered(body: Node) -> void:
	if _buffer > 0.0 or _armed: return
	
	count += 1
	
	if count >= count_to_arm:
		arm()
	else:
		if sfx_impact: sfx_impact.play()
	
	_buffer += impact_delay_buffer
	
