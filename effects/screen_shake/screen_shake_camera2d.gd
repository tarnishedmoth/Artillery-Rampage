## Adapted from https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html
class_name ScreenShakeCamera2D extends Camera2D

@export var decay: float = 0.8
@export var max_offset: Vector2= Vector2(10, 100)
@export var max_roll: float = 0.05
@export var trauma_power: float = 2.0

@export var noise_template : FastNoiseLite
@export var randomize_seed:bool = true
var _noise:FastNoiseLite

var trauma: float = 0.0
var noise_y: float= 0.0

func _ready():
	_noise = _generate_noise()
	make_current()

func add_trauma(amount: float):
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta):
	if trauma > 0.0:
		trauma = maxf(trauma - decay * delta, 0.0)
		shake()

func shake():
	var amt:float = pow(trauma, trauma_power)
	noise_y += 1.0
	
	offset.x = clampf(max_offset.x * amt * _noise.get_noise_2d(_noise.seed * 2, noise_y), -max_offset.x, max_offset.x)
	offset.y = clampf(max_offset.y * amt * _noise.get_noise_2d(_noise.seed * 3, noise_y), -max_offset.y, max_offset.y)
	rotation = clampf(max_roll * amt * _noise.get_noise_2d(_noise.seed, noise_y), -max_roll, max_roll)

func _generate_noise() -> FastNoiseLite:
	var noise : FastNoiseLite
	
	if noise_template:
		noise = noise_template.duplicate()
	else:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		
	if randomize_seed:
		noise.seed = randi()
	
	print_debug("%s - Using seed=%d for noise" % [name, noise.seed])
	
	return noise
