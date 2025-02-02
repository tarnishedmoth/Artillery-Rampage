class_name AITank extends TankController

@onready var _tank:Tank = $Tank

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# TODO: Disabling gravity initially for AI tanks
	tank.toggle_gravity(false)

func begin_turn():
	print("AI began turn")
	pass

func _get_tank():
	return _tank
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_tank_tank_killed(tank: Tank, instigatorController: Node2D, weapon: WeaponProjectile) -> void:
	tank.kill()
	queue_free()


func _on_tank_tank_took_damage(tank: Tank, instigatorController: Node2D, weapon: WeaponProjectile, amount: float) -> void:
	pass # Replace with function body.
