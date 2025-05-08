class_name FallDamageCauser extends Node

var _nearest_distance: float = 1e12
var _nearest_owner:TankController = null

func _ready() -> void:
	GameEvents.took_damage.connect(_on_object_took_damage)
	GameEvents.turn_started.connect(_on_turn_started)

var instigator_controller:TankController:
	get:
		return _nearest_owner
		
		
func _on_object_took_damage(object: Node, hit_controller: Node2D, _instigator: Node2D, contact_point: Vector2, damage: float) -> void:
	var object_root:Node = Groups.get_parent_in_group(object, Groups.DamageableRoot)

	if object_root is not Terrain or hit_controller is not TankController:
		return

	print_debug("%s: object=%s hit_controller=%s instigator=%s contact_point=%s damage=%f" % [name, object.name, hit_controller.name, _instigator.name, contact_point, damage])

	# Calculate dist squared to the contact_point
	var dist_squared: float = owner.global_position.distance_squared_to(contact_point)

	if dist_squared < _nearest_distance:
		print_debug("%s: Found new nearest terrain hit on %s by %s at distance %f" % [name, object.name, hit_controller.name, dist_squared])
		_nearest_distance = dist_squared
		_nearest_owner = hit_controller

func _on_turn_started(controller: TankController) -> void:
	if controller == owner.owner:
		print_debug("%s: Resetting terrain damage tracking at start of turn for %s" % [name, owner.owner])
		# Reset the nearest projectile distance and owner at the start of each turn
		_nearest_distance = 1e12
		_nearest_owner = null
