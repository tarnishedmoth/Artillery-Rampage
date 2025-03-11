# scrolls the background texture (clouds in the sky)
# TODO: update speed based on wind speed

extends TextureRect

var scrollpos = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var WIND_SPEED = -20 # FIXME - get the proper value
	scrollpos += delta*WIND_SPEED # scroll
	# loop around
	if scrollpos > 600: scrollpos -= 600
	if scrollpos < -600: scrollpos += 600
	# depreciated way to sxroll the texture UVs:
	# texture.region = Rect2(fmod(age,600), 0, 600, 600)
	# move the actual sprite and loop back around
	position.x = scrollpos
