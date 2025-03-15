extends Node

@export var max_health:float = 100

@onready var health_label = $HealthLabel

@onready var health_bar = $HouseHealthbar
@onready var health_bar_current_health = $HouseHealthbar/GreenPart

var health: float

#var image = Image.load_from_file("res://buildings/house.png") # This method only works during development per ImageTexture documentation
var image_resource = load("res://buildings/house.png")
var image: Image = image_resource.get_image()
var texture = ImageTexture.create_from_image(image)

func _ready() -> void:
	health = max_health
	# replace CompressedTexture2D with an editable texture
	$HouseBody/HouseBodySprite.texture = texture

#region Damage and Death
@warning_ignore("unused_parameter")
func take_damage(instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	# dampen damage taken so the house lasts longer
	amount = amount / 2

	var orig_health = health
	health = clampf(health - amount, 0, max_health)
	var actual_damage = orig_health - health
	
	if is_zero_approx(actual_damage):
		print("House " + get_parent().name + " didn't take any actual damage")
		return
	
	print("House " + get_parent().name + " took " + str(actual_damage) + " damage; health=" + str(health))
	
	health_label.text = str(health)
	health_bar.visible = true
	health_bar_current_health.scale.x = health / max_health
	
	if health <= 0:
		queue_free()
	else:
		# randomly erase pixels from the image
		# eventually these will be shingle-sized rects rather than individual pixels
		for x in range(0,image.get_width()):
			for y in range(0,image.get_height()):
				var chance_to_erase = 0.525 * (1 - (randf() * health / max_health))
				if chance_to_erase > 0.5:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
		$HouseBody/HouseBodySprite.texture.update(image)

#endregion
