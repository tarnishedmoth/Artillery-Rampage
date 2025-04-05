class_name MegaNukeExplosion extends Sprite2D

@export var lifetime: float = 5.0

var shader:ShaderMaterial

## Callable for current game time
## Set by PostProcessingEffects when added to the tree
var get_game_time_seconds:Callable

func _ready() -> void:
		
	shader = material as ShaderMaterial
	if not shader:
		push_error("missing shader parameter")
		return
		
	var viewport_size:Vector2 = get_viewport().get_visible_rect().size
	# Adjust the node's size
	self.position = Vector2.ZERO  # Place the node at the top-left corner
	self.scale = viewport_size

	shader.set_shader_parameter("start_time", get_game_time_seconds.call())
	
	GameEvents.turn_started.connect(_on_turn_started)

	if lifetime > 0:
		shader.set_shader_parameter("lifetime", lifetime)
		await get_tree().create_timer(lifetime).timeout
		queue_free()
	
func _on_turn_started(player: TankController) -> void:
	print_debug("%s - TurnStarted: %s" % [name, player.name])
	# TODO: Fade out the effect
