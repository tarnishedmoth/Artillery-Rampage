# scrolls the background texture (clouds in the sky)

extends TextureRect

## Controls speed of scrolling background based on the wind force
@export_group("Scrolling")
@export_range(0, 1e9, 0.01, "or_greater")
var wind_scoll_scale:float = 1.0

## Minimum scroll speed to use if wind is insufficient
## Useful if always want the background moving a little
@export_group("Scrolling")
@export_range(0, 1e9, 0.01, "or_greater")
var min_wind_scroll_speed:float = 0.0

var scroll_speed:float
var background_size:float
var original_material:Material

# Called when the node enters the scene tree for the first time.
func _ready():
	original_material = material
	background_size = get_viewport_rect().size.x
	# Background is higher sibling in GameLevel tree than Wind so our _ready will execute first
	GameEvents.wind_updated.connect(_update_scrolling)

func _update_scrolling(wind_node: Wind) -> void:
	if not original_material:
		push_warning("Background - no shader material set - scrolling disabled!")
		return

	scroll_speed = wind_node.wind.x * wind_scoll_scale
	if absf(scroll_speed) < min_wind_scroll_speed:		
		print_debug("Background - abs(scroll_speed)=%f is below min scroll speed=%fl using min scroll speed" % [absf(scroll_speed), min_wind_scroll_speed])
		scroll_speed = min_wind_scroll_speed * (signf(scroll_speed) if not is_zero_approx(scroll_speed) else signf(randf() - 0.5))
	# Scale scroll speed to uv space
	var uv_speed:float = -scroll_speed / background_size		
	
	print_debug("Background - scroll_speed=%f; uv_speed=%f;" % [scroll_speed, uv_speed])
	
	if is_zero_approx(uv_speed):
		print_debug("No UV speed - disabling shader")
		material = null
	else:
		material = original_material
		material.set_shader_parameter("speed", uv_speed)
